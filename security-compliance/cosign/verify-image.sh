#!/usr/bin/env bash
# security-compliance/cosign/verify-image.sh
# Verifies Cosign keyless signature on a container image
# Usage: ./verify-image.sh <image-ref>
# Example: ./verify-image.sh ghcr.io/bam1e/secure-api@sha256:abc123

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

IMAGE_REF="${1:-}"

if [[ -z "$IMAGE_REF" ]]; then
  echo -e "${RED}Usage: $0 <image-ref>${NC}"
  echo "Example: $0 ghcr.io/bam1e/secure-api@sha256:abc123"
  exit 1
fi

echo -e "${YELLOW}Verifying Cosign signature for: ${IMAGE_REF}${NC}"

# Verify keyless signature from GitHub Actions OIDC
cosign verify \
  --certificate-identity-regexp "https://github.com/bam1e/enterprise-gitops-blueprint/.github/workflows/ci-engine.yml@refs/heads/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  "${IMAGE_REF}" | jq .

if [[ $? -eq 0 ]]; then
  echo -e "${GREEN}✅ Image signature verified successfully!${NC}"
  echo -e "${GREEN}Image: ${IMAGE_REF}${NC}"
else
  echo -e "${RED}❌ Image signature verification FAILED!${NC}"
  echo -e "${RED}Do not deploy this image — it may be tampered.${NC}"
  exit 1
fi
