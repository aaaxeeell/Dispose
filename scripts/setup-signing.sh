#!/bin/bash
# One-time: creates a self-signed "Ribbon Local Signing" certificate in the
# login keychain. Builds signed with it keep the same identity, so macOS
# remembers the Accessibility permission across rebuilds (ad-hoc builds don't).
set -euo pipefail
NAME="Ribbon Local Signing"
if security find-certificate -c "$NAME" >/dev/null 2>&1; then
  echo "\"$NAME\" already exists."; exit 0
fi
OPENSSL=$(command -v /opt/homebrew/bin/openssl || command -v openssl)
D=$(mktemp -d); trap 'rm -rf "$D"' EXIT
cat > "$D/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF
"$OPENSSL" req -x509 -newkey rsa:2048 -nodes -keyout "$D/key.pem" -out "$D/cert.pem" \
  -days 3650 -config "$D/cert.cnf" 2>/dev/null
PASS=$("$OPENSSL" rand -hex 16)
LEGACY=$("$OPENSSL" version | grep -q '^OpenSSL 3' && echo -legacy || true)
"$OPENSSL" pkcs12 -export $LEGACY -inkey "$D/key.pem" -in "$D/cert.pem" -name "$NAME" \
  -out "$D/id.p12" -passout "pass:$PASS"
security import "$D/id.p12" -k ~/Library/Keychains/login.keychain-db -P "$PASS" -T /usr/bin/codesign
echo "Created \"$NAME\". Rebuild with scripts/build-app.sh."
