#!/usr/bin/env bash
set -euo pipefail

# Based off of https://jamielinux.com/docs/openssl-certificate-authority/index.html

BASE="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"
OUT="${BASE}/certs"
CA_CHAIN="${OUT}/certs/ca-chain.cert.pem"

# This way we don't have to keep passing `-config "path/to/openssl.cnf"`
# See also `man config.5ssl`
export OPENSSL_CONF="${BASE}/openssl.cnf"
# This is observed within `openssl.cnf`
export CERT_BASEDIR="${OUT}"

mkdir -p "$OUT"

announce() {
  printf '>>>  %b\n' "$*" >&2
}

verify_valid_x509_cert() {
  local cert
  cert="$1"

  openssl x509 -noout -text -in "$cert" >/dev/null
}

verify_cert() {
  local cert chain purpose
  cert="$1"
  chain="$2"
  purpose="$3"

  openssl verify -purpose "$purpose" -trusted "$chain" -partial_chain "$cert" >/dev/null
}

announce 'Reverting workspace back to clean state'
rm -rf "$OUT"
mkdir -p "$OUT"

announce 'Setting up workspace'
mkdir "$OUT"/{certs,csr,private}
mkdir "$OUT"/{root,int}-{crl,issued-certs}
chmod 700 "$OUT"/private

# initialize plaintext databases
touch "$OUT"/{root,int}-index
# initial serialnum
printf '1000\n' | tee "$OUT"/{root,int}-{serial,crlnumber} >/dev/null

announce 'Creating root certificate authority'
openssl genrsa -out "${OUT}/private/root.key.pem" 4096 >/dev/null 2>&1
openssl req -batch -new -x509 -days 9999 -sha256 -extensions v3_root_ca \
  -subj '/C=US/ST=Denial/O=Contoso/CN=Insecure Demo Root CA' \
  -key "${OUT}/private/root.key.pem" \
  -out "${OUT}/certs/root.cert.pem"

announce 'Verifying the root CA certificate'
verify_valid_x509_cert "${OUT}/certs/root.cert.pem"

announce 'Creating intermediate certificate authority key'
openssl genrsa -out "${OUT}/private/intermediate.key.pem" 4096 >/dev/null 2>&1
announce "Generating the Certificate Signing Request (CSR) for the intermediate authority's certificate"
openssl req -batch -new -extensions v3_intermediate_ca \
  -subj '/C=US/ST=Denial/O=Contoso/CN=Insecure Demo Intermediate CA' \
  -key "${OUT}/private/intermediate.key.pem" \
  -out "${OUT}/csr/intermediate.csr.pem" >/dev/null 2>&1
announce "Satisfying the CSR with root authority's key, generating the intermediate authority certificate"
openssl ca -batch -notext -name 'CA_root' \
  -extensions v3_intermediate_ca \
  -in "${OUT}/csr/intermediate.csr.pem" \
  -out "${OUT}/certs/intermediate.cert.pem" >/dev/null 2>&1
announce "Verifying intermediate authority's certificate"
verify_valid_x509_cert \
  "${OUT}/certs/intermediate.cert.pem"
openssl verify -purpose 'any' -trusted "${OUT}/certs/root.cert.pem" "${OUT}/certs/intermediate.cert.pem" >/dev/null

announce "Generate certificate authority chain from root and intermediate authority certificates"
cat "${OUT}/certs/intermediate.cert.pem" \
  "${OUT}/certs/root.cert.pem" > "$CA_CHAIN"

announce 'Creating HTTPS server key'
openssl genrsa -out "${OUT}/private/server-localhost.key.pem" 4096 >/dev/null 2>&1
announce "Generating the Certificate Signing Request (CSR) for the HTTPS server's certificate"
openssl req -batch -new -sha256 \
  -subj '/C=US/ST=Denial/O=Contoso/CN=127.0.0.1' \
  -key "${OUT}/private/server-localhost.key.pem" \
  -out "${OUT}/csr/server-localhost.csr.pem" >/dev/null 2>&1
announce "Satisfying the CSR with intermediate authority's key, generating the HTTPS server certificate"
openssl ca -batch -name 'CA_intermediate' \
  -extensions server_cert -days 365 \
  -in "${OUT}/csr/server-localhost.csr.pem" \
  -out "${OUT}/certs/server-localhost.cert.pem" >/dev/null 2>&1
announce 'Verifying HTTPS server certificate'
verify_valid_x509_cert \
  "${OUT}/certs/server-localhost.cert.pem"
if ! openssl verify -purpose sslserver -trusted "${OUT}/certs/ca-chain.cert.pem" -partial_chain "${OUT}/certs/server-localhost.cert.pem" >/dev/null 2>&1
then
  announce 'ERROR: HTTPS server certificate did not validate as OK'
  exit 1
fi
announce 'Embedding HTTPS server certificate with full chain'
cat "${OUT}/certs/server-localhost.cert.pem" \
  "${OUT}/certs/intermediate.cert.pem" \
  "${OUT}/certs/root.cert.pem" > "${OUT}/certs/server-localhost.chain.pem"

announce 'Creating client key'
openssl genrsa -out "${OUT}/private/client.key.pem" 4096 >/dev/null 2>&1
announce "Generating the Certificate Signing Request (CSR) for the client's certificate"
openssl req -batch -new -sha256 \
  -subj '/C=US/ST=Denial/O=Contoso/CN=Insecure Demo Client' \
  -key "${OUT}/private/client.key.pem" \
  -out "${OUT}/csr/client.csr.pem" >/dev/null 2>&1
announce "Satisfying the CSR with intermediate authority's key, generating the client certificate"
openssl ca -batch -name 'CA_intermediate' \
  -extensions usr_cert -days 365 -notext \
  -in "${OUT}/csr/client.csr.pem" \
  -out "${OUT}/certs/client.cert.pem" >/dev/null 2>&1
announce 'Verifying client certificate'
verify_valid_x509_cert \
  "${OUT}/certs/client.cert.pem"
if ! verify_cert "${OUT}/certs/client.cert.pem" \
  "${OUT}/certs/ca-chain.cert.pem" sslclient
then
  announce 'ERROR: Client certificate did not validate as OK'
  exit 1
fi
announce 'Embedding client certificate with full chain'
cat "${OUT}/certs/client.cert.pem" \
  "${OUT}/certs/intermediate.cert.pem" \
  "${OUT}/certs/root.cert.pem" > "${OUT}/certs/client.chain.pem"

announce 'Creating self-signed client key'
openssl genrsa -out "${OUT}/private/client-self-signed.key.pem" >/dev/null 2>&1
announce "Generating the self-signed client certificate"
openssl req -batch -new -x509 -sha256 \
  -extensions usr_cert -days 365 \
  -subj '/C=US/ST=Denial/O=Contoso/CN=Insecure Demo Self-Signed Client' \
  -key "${OUT}/private/client-self-signed.key.pem" \
  -out "${OUT}/certs/client-self-signed.cert.pem" >/dev/null 2>&1
announce 'Verifying self-signed client certificate'
verify_valid_x509_cert \
  "${OUT}/certs/client-self-signed.cert.pem"
if verify_cert "${OUT}/certs/client-self-signed.cert.pem" \
  "${OUT}/certs/ca-chain.cert.pem" sslclient 2>/dev/null
then
  announce 'ERROR: Self-signed client certificate did validate as part of the CA chain. Expected it to register as invalid.'
  exit 1
fi
announce 'Embedding self-signed client certificate with full chain'
cat "${OUT}/certs/client-self-signed.cert.pem" \
  "${OUT}/certs/intermediate.cert.pem" \
  "${OUT}/certs/root.cert.pem" > "${OUT}/certs/client-self-signed.chain.pem"

announce 'Creating expired client key'
openssl genrsa -out "${OUT}/private/client-expired.key.pem" >/dev/null 2>&1
announce "Generating the Certificate Signing Request (CSR) for the expired client's certificate"
openssl req -batch -new -sha256 \
  -subj '/C=US/ST=Denial/O=Contoso/CN=Insecure Demo Client EXPIRED' \
  -key "${OUT}/private/client-expired.key.pem" \
  -out "${OUT}/csr/client-expired.csr.pem" >/dev/null 2>&1
announce "Satisfying the CSR with intermediate authority's key, generating the expired client certificate"
openssl ca -batch -name 'CA_intermediate' \
  -extensions usr_cert -notext \
  -startdate 200801010000Z -enddate 201001010000Z \
  -in "${OUT}/csr/client-expired.csr.pem" \
  -out "${OUT}/certs/client-expired.cert.pem" >/dev/null 2>&1
announce 'Verifying expired client certificate'
verify_valid_x509_cert \
  "${OUT}/certs/client-expired.cert.pem"

if ! (openssl verify -purpose 'sslclient' -trusted "$CA_CHAIN" -partial_chain "${OUT}/certs/client-expired.cert.pem" 2>&1 || true) | grep -qFe 'has expired' >/dev/null
then
  announce 'ERROR: Expired client certificate validated as OK. Expected it to be invalid.'
  exit 1
fi
announce 'Embedding expired client certificate with full chain'
cat "${OUT}/certs/client-expired.cert.pem" \
  "${OUT}/certs/intermediate.cert.pem" \
  "${OUT}/certs/root.cert.pem" > "${OUT}/certs/client-expired.chain.pem"


chmod 400 "${OUT}/private"/*.pem
chmod 444 "${OUT}/certs/"*.pem "${OUT}/csr/"*.pem
