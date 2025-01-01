#!/bin/bash

# Default parameters
WORKDIR="certs"
PASSWORD="garlic"
ALGORITHM="SM2"  # Options: SM2, RSA, ECC
TONGSUO_BIN_PATH="/usr/local/tongsuo/bin"
LD_LIBRARY_PATH_OVERRIDE="/usr/local/tongsuo/lib"
UNENCRYPTED_KEYS=false  # Default: private keys are encrypted
COMMONNAME="test.example.com"

# Help function
show_help() {
    cat <<EOF
Usage: $0 [options]

Options:
  -p PASSWORD          Set password for private keys (default: garlic)
  -a ALGORITHM         Choose algorithm: SM2, RSA, ECC (default: SM2)
  -o OUTPUT_DIR        Specify output directory for certificates (default: certs)
  -t TONGSUO_BIN_PATH  Specify the Tongsuo binary path (default: /usr/local/tongsuo/bin)
  -l LD_LIBRARY_PATH   Specify the LD_LIBRARY_PATH for dynamic libraries (default: /usr/local/tongsuo/lib)
  -n COMMON NAME       Specify Common Name
  -u                   Generate unencrypted private keys
  -h                   Show this help message

Description:
  This script generates a certificate chain with specified algorithms.
  It supports SM2 (Commercial Cryptography Scheme in China), RSA, and ECC.

Output Structure:
  - Root CA private key and certificate
  - Intermediate CA private key, CSR, and certificate
  - Server signing and encryption certificates
  - Full certificate chains for signing and encryption (SM2 only)
EOF
}

# Parse input parameters
while getopts "p:a:o:t:l:uhn:" opt; do
    case "${opt}" in
        p) PASSWORD="${OPTARG}" ;;
        a) ALGORITHM="${OPTARG}" ;;
        o) WORKDIR="${OPTARG}" ;;
        t) TONGSUO_BIN_PATH="${OPTARG}" ;;
        l) LD_LIBRARY_PATH_OVERRIDE="${OPTARG}" ;;
        n) COMMONNAME="${OPTARG}";;
        u) UNENCRYPTED_KEYS=false ;;
        h) show_help; exit 0 ;;
        *) echo "Invalid option. Use -h for help." && exit 1 ;;
    esac
done

# Validate algorithm
if [[ "$ALGORITHM" != "SM2" && "$ALGORITHM" != "RSA" && "$ALGORITHM" != "ECC" ]]; then
    echo "Unsupported algorithm: $ALGORITHM. Use SM2, RSA, or ECC."
    exit 1
fi

# Tool and hash selection
if [[ "$ALGORITHM" == "SM2" ]]; then
    TOOL="$TONGSUO_BIN_PATH/tongsuo"
    DEFAULT_MD="sm3"
else
    TOOL="openssl"
    DEFAULT_MD="sha256"
fi


# Temporary environment configuration for Tongsuo
export PATH="$TONGSUO_BIN_PATH:$PATH"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH_OVERRIDE:$LD_LIBRARY_PATH"

# Create working directory
mkdir -p "$WORKDIR"

# File paths
CA_KEY="$WORKDIR/ca.key.pem"
CA_CERT="$WORKDIR/ca.cert.pem"
INTERMEDIATE_KEY="$WORKDIR/intermediate.key.pem"
INTERMEDIATE_CERT="$WORKDIR/intermediate.cert.pem"
SERVER_KEY="$WORKDIR/server.key.pem"
SERVER_CERT="$WORKDIR/server.cert.pem"
SERVER_ENC_KEY="$WORKDIR/server_enc.key.pem"
SERVER_ENC_CERT="$WORKDIR/server_enc.cert.pem"
SIGN_CHAIN_FILE="$WORKDIR/sign_full_chain.pem"
ENC_CHAIN_FILE="$WORKDIR/enc_full_chain.pem"
CONFIG_FILE="$WORKDIR/openssl.cnf"

# Create OpenSSL configuration file dynamically
cat > "$CONFIG_FILE" <<EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = $WORKDIR
private_key       = $CA_KEY
certificate       = $CA_CERT
default_md        = $DEFAULT_MD
default_days      = 375
policy            = policy_strict

[ policy_strict ]
countryName             = match
stateOrProvinceName     = optional
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = 2048
default_md          = $DEFAULT_MD
distinguished_name  = req_distinguished_name
x509_extensions     = v3_ca

[ req_distinguished_name ]
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = $COMMONNAME
emailAddress                    = Email Address

countryName_default             = CN
organizationName_default        = TestOrg
commonName_default              = Root CA

[ v3_ca ]
basicConstraints = critical,CA:TRUE
keyUsage = critical, cRLSign, keyCertSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always

[ v3_intermediate_ca ]
basicConstraints = critical,CA:TRUE, pathlen:0
keyUsage = critical, cRLSign, keyCertSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always

[ v3_server_cert ]
basicConstraints = critical,CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always

[ v3_server_enc_cert ]
basicConstraints = critical,CA:FALSE
keyUsage = keyEncipherment, dataEncipherment, keyAgreement
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
EOF

# Function to generate private key
generate_private_key() {
    local key_path="$1"
    if [[ "$ALGORITHM" == "ECC" ]]; then
        $TOOL ecparam -name prime256v1 -genkey -out "$key_path" || exit 1
    elif $UNENCRYPTED_KEYS; then
        $TOOL genpkey -algorithm $ALGORITHM -out "$key_path" || exit 1
    else
        $TOOL genpkey -algorithm $ALGORITHM -aes256 -out "$key_path" -pass pass:"$PASSWORD" || exit 1
    fi
}

# Generate Root CA
echo "Generating Root CA..."
generate_private_key "$CA_KEY"
$TOOL req -x509 -days 3650 -key "$CA_KEY" -out "$CA_CERT" -passin pass:"$PASSWORD" \
    -subj "/C=CN/O=TestOrg/CN=Root CA" \
    -config "$CONFIG_FILE" -extensions v3_ca || exit 1

# Generate Intermediate CA
echo "Generating Intermediate CA..."
generate_private_key "$INTERMEDIATE_KEY"
$TOOL req -new -key "$INTERMEDIATE_KEY" -out "$WORKDIR/intermediate.csr" -passin pass:"$PASSWORD" \
    -subj "/C=CN/O=TestOrg/CN=Intermediate CA" || exit 1
$TOOL x509 -req -days 1825 -in "$WORKDIR/intermediate.csr" -CA "$CA_CERT" -CAkey "$CA_KEY" \
    -CAcreateserial -out "$INTERMEDIATE_CERT" -passin pass:"$PASSWORD" \
    -extfile "$CONFIG_FILE" -extensions v3_intermediate_ca || exit 1

# Generate Server Signing Certificate
echo "Generating Server Signing Certificate..."
generate_private_key "$SERVER_KEY"
$TOOL req -new -key "$SERVER_KEY" -out "$WORKDIR/server.csr" -passin pass:"$PASSWORD" \
    -subj "/C=CN/O=TestOrg/CN=$COMMONNAME" || exit 1
$TOOL x509 -req -days 365 -in "$WORKDIR/server.csr" -CA "$INTERMEDIATE_CERT" -CAkey "$INTERMEDIATE_KEY" \
    -CAcreateserial -out "$SERVER_CERT" -passin pass:"$PASSWORD" \
    -extfile "$CONFIG_FILE" -extensions v3_server_cert || exit 1

# Generate Server Encryption Certificate (if SM2)
if [[ "$ALGORITHM" == "SM2" ]]; then
    echo "Generating Server Encryption Certificate..."
    generate_private_key "$SERVER_ENC_KEY"
    $TOOL req -new -key "$SERVER_ENC_KEY" -out "$WORKDIR/server_enc.csr" -passin pass:"$PASSWORD" \
        -subj "/C=CN/O=TestOrg/CN=$COMMONNAME" || exit 1
    $TOOL x509 -req -days 365 -in "$WORKDIR/server_enc.csr" -CA "$INTERMEDIATE_CERT" -CAkey "$INTERMEDIATE_KEY" \
        -CAcreateserial -out "$SERVER_ENC_CERT" -passin pass:"$PASSWORD" \
        -extfile "$CONFIG_FILE" -extensions v3_server_enc_cert || exit 1
fi

# Generate Full Certificate Chains
echo "Creating Full Certificate Chains..."
cat "$SERVER_CERT" "$INTERMEDIATE_CERT" "$CA_CERT" > "$SIGN_CHAIN_FILE"
if [[ "$ALGORITHM" == "SM2" ]]; then
     cat "$SERVER_ENC_CERT" "$INTERMEDIATE_CERT" "$CA_CERT" > "$ENC_CHAIN_FILE"
fi

# Display generated files
echo "Certificates generated successfully!"
echo "Root CA Certificate:        $CA_CERT"
echo "Intermediate CA Certificate:$INTERMEDIATE_CERT"
echo "Server Signing Certificate: $SERVER_CERT"
if [[ "$ALGORITHM" == "SM2" ]]; then
    echo "Server Encryption Certificate: $SERVER_ENC_CERT"
    echo "Encryption Certificate Chain: $ENC_CHAIN_FILE"
fi
echo "Signing Certificate Chain:  $SIGN_CHAIN_FILE"

