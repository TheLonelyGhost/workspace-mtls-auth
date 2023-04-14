# Workspace: mTLS Certificates

This repository serves as a sandbox in which to tinker with mutual TLS communication. Included are some shell scripts that generate valid TLS certificates in the following roles:

- Root Certificate Authority
- Intermediate Certificate Authority
- Web Server (HTTPS)
- Client

Also included are various examples of invalid client TLS certificates, due to any one of the following reasons:

- Self-signed
- Expired
- Incorrect TLS "key usage" attribute

## Usage

```bash
~/src $ ./generate.sh

>>>  Reverting workspace back to clean state
>>>  Setting up workspace
>>>  Creating root certificate authority
>>>  Verifying the root CA certificate
>>>  Creating intermediate certificate authority key
>>>  Generating the Certificate Signing Request (CSR) for the intermediate authority's certificate
>>>  Satisfying the CSR with root authority's key, generating the intermediate authority certificate
>>>  Verifying intermediate authority's certificate
>>>  Generate certificate authority chain from root and intermediate authority certificates
>>>  Creating HTTPS server key
>>>  Generating the Certificate Signing Request (CSR) for the HTTPS server's certificate
>>>  Satisfying the CSR with intermediate authority's key, generating the HTTPS server certificate
>>>  Verifying HTTPS server certificate
>>>  Embedding HTTPS server certificate with full chain
>>>  Creating client key
>>>  Generating the Certificate Signing Request (CSR) for the client's certificate
>>>  Satisfying the CSR with intermediate authority's key, generating the client certificate
>>>  Verifying client certificate
>>>  Embedding client certificate with full chain
>>>  Creating self-signed client key
>>>  Generating the self-signed client certificate
>>>  Verifying self-signed client certificate
>>>  Embedding self-signed client certificate with full chain
>>>  Creating expired client key
>>>  Generating the Certificate Signing Request (CSR) for the expired client's certificate
>>>  Satisfying the CSR with intermediate authority's key, generating the expired client certificate
>>>  Verifying expired client certificate
>>>  Embedding expired client certificate with full chain

~/src $ tree ./certs

./certs
├── certs
│   ├── ca-chain.cert.pem
│   ├── client-expired.cert.pem
│   ├── client-expired.chain.pem
│   ├── client-self-signed.cert.pem
│   ├── client-self-signed.chain.pem
│   ├── client.cert.pem
│   ├── client.chain.pem
│   ├── intermediate.cert.pem
│   ├── root.cert.pem
│   ├── server-localhost.cert.pem
│   └── server-localhost.chain.pem
├── csr
│   ├── client-expired.csr.pem
│   ├── client.csr.pem
│   ├── intermediate.csr.pem
│   └── server-localhost.csr.pem
├── int-crl
├── int-crlnumber
├── int-index
├── int-index.attr
├── int-index.attr.old
├── int-index.old
├── int-issued-certs
│   ├── 1000.pem
│   ├── 1001.pem
│   └── 1002.pem
├── int-serial
├── int-serial.old
├── private
│   ├── client-expired.key.pem
│   ├── client-self-signed.key.pem
│   ├── client.key.pem
│   ├── intermediate.key.pem
│   ├── root.key.pem
│   └── server-localhost.key.pem
├── root-crl
├── root-crlnumber
├── root-index
├── root-index.attr
├── root-index.old
├── root-issued-certs
│   └── 1000.pem
├── root-serial
└── root-serial.old

7 directories, 38 files

```

Now there are certificates in the `certs/` directory, relative to the root of the repository. We can dissect what happens in `generate.sh` on a line-by-line basis and reference it against the directives given in the heavily-annotated `openssl.cnf`.

## Why are these implemented as shell scripts?

What better way to show how a tool that is often installed by default in \*nix platforms can be used to configure secure connections?

In all seriousness, these are shell scripts. They can and should be changed to fit your needs. Feel free to experiment and make changes to the settings set in the commands and configuration files.

## Why is this a git repository?

Rather than a blog post which just tells you about mutual TLS in a broad sense, I like showing a lot better. I also happen to feel more empowered to experiment and dig in and break things when I know I have an environment which has a reset button. Since this is a publicly hosted git repository, the ultimate reset button is `rm -rf ./my-git-repo && git clone <this-repo>`.

Make sweeping changes. Do whatever you like. The whole point is to provide a safe, resetable space in which to experiment!

## How do I use these generated certificates?

That's the beauty of it. The default behavior of this repo is to just generate valid X.509 certificates for use with TLS connections. This could be mutual TLS, classic HTTPS server usage (no client cert), or exploring other usages within the X.509v3 specification. It's ultimately up to you!

One use case is to stand up an HTTPS server with your favorite language (e.g., Go, Python, etc.) and implement an application that optionally accepts mutual TLS connections. Maybe you want to require mTLS. The how of that part is up to you. I typically prefer the simplest possible solution, so my usage with a client typically looks something like `curl --key ./path/to/key.pem --cert ./path/to/cert.pem https://127.0.0.1:8443/whoami`.

## What is still missing?

- source code for a sample implementation of an HTTPS server using mTLS, configured to use these generated certs
- automated tests to verify if each cert is well-formed for its role (i.e., would most TLS implementations recognize the intermediate CA as a certificate authority?)
- explanation of why `flake.nix` and `flake.lock` are present in the repository

