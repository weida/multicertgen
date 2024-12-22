# multicertgen

A versatile SSL/TLS certificate generation tool supporting SM2, RSA, and ECC algorithms. `multicertgen` simplifies the process of generating certificate chains for global and Chinese cryptographic standards.

---

## Features

- **Multi-Algorithm Support**: Generate SSL/TLS certificates using SM2 (via Tongsuo), RSA, and ECC.
- **Flexible Key Options**: Create encrypted or unencrypted private keys.
- **Full Certificate Chain Creation**: Includes root, intermediate, server signing, and encryption certificates.
- **Seamless Tool Integration**: Works with OpenSSL and Tongsuo cryptographic libraries.
- **Customizable Output Paths**: Define output directories for organized certificate storage.

---

## Prerequisites

Ensure your system has the following installed:

- **Cryptographic Tools**:
  - Tongsuo (`/usr/local/tongsuo/bin/tongsuo`)
  - OpenSSL (if using RSA or ECC)
- **Environment Configuration** (for Tongsuo):
  - Add the Tongsuo binary and library paths to your system:
    ```bash
    export PATH="/usr/local/tongsuo/bin:$PATH"
    export LD_LIBRARY_PATH="/usr/local/tongsuo/lib:$LD_LIBRARY_PATH"
    ```

---

## Usage

### Basic Syntax
```bash
./ssl_cert_chain_tool.sh [options]
```

### Options
- `-p PASSWORD` (default: `garlic`)  
  Set password for private keys.
- `-a ALGORITHM` (default: `SM2`)  
  Choose the algorithm: `SM2`, `RSA`, or `ECC`.
- `-o OUTPUT_DIR` (default: `certs`)  
  Specify the output directory for generated certificates.
- `-t TONGSUO_BIN_PATH` (default: `/usr/local/tongsuo/bin`)  
  Define the Tongsuo binary path.
- `-l LD_LIBRARY_PATH` (default: `/usr/local/tongsuo/lib`)  
  Set the library path for Tongsuo dynamic libraries.
- `-u`  
  Generate unencrypted private keys.
- `-h`  
  Display the help message.

---

## Examples

### Generate SM2 Certificates with Encrypted Keys
```bash
./ssl_cert_chain_tool.sh -a SM2 -o smcerts -p mypassword
```

### Generate RSA Certificates with Unencrypted Keys
```bash
./ssl_cert_chain_tool.sh -a RSA -u -o rsacerts
```

### Generate ECC Certificates with Default Options
```bash
./ssl_cert_chain_tool.sh -a ECC -o ecccers
```

---

## Output Structure

The generated files will be organized as follows:
```
certs/
├── ca.key.pem                 # Root CA private key
├── ca.cert.pem                # Root CA certificate
├── intermediate.key.pem       # Intermediate CA private key
├── intermediate.cert.pem      # Intermediate CA certificate
├── server.key.pem             # Server signing private key
├── server.cert.pem            # Server signing certificate
├── server_enc.key.pem         # Server encryption private key (SM2 only)
├── server_enc.cert.pem        # Server encryption certificate (SM2 only)
├── sign_full_chain.pem        # Full chain for signing
└── enc_full_chain.pem         # Full chain for encryption (SM2 only)
```

---
