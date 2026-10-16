#!/usr/bin/env bash
# Download the shared SSH private key from Secrets Manager into ./keys (git-ignored).
# Usage: scripts/fetch-keys.sh [prefix]   (default prefix: grafana-sandbox)
set -euo pipefail

PREFIX="${1:-grafana-sandbox}"
REGION="${AWS_REGION:-ap-southeast-2}"
DEST="$(cd "$(dirname "$0")/.." && pwd)/keys"

mkdir -p "$DEST"
chmod 700 "$DEST"

# Refuse to write keys anywhere git would track them.
if ! git -C "$DEST" check-ignore -q "$DEST/$PREFIX-test.pem"; then
  echo "ERROR: $DEST is not git-ignored; aborting." >&2
  exit 1
fi

file="$DEST/$PREFIX.pem"
rm -f "$file"   # a previous copy is read-only (chmod 400)
aws secretsmanager get-secret-value \
  --region "$REGION" \
  --secret-id "$PREFIX/ssh-private-key" \
  --query SecretString --output text > "$file"
chmod 400 "$file"
echo "saved $file"

echo
echo "Connect with, for example:"
echo "  ssh -i keys/$PREFIX.pem ec2-user@$PREFIX-prometheus.labs3.dnx.host"
