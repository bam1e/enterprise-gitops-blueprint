#!/usr/bin/env bash
# security-compliance/sbom/analyse-sbom.sh
# Downloads and analyses the SBOM for a given image
# Checks for known vulnerabilities using Grype
# Usage: ./analyse-sbom.sh <image-ref>

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

IMAGE_REF="${1:-}"

if [[ -z "$IMAGE_REF" ]]; then
  echo -e "${RED}Usage: $0 <image-ref>${NC}"
  exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}SBOM Analysis for: ${IMAGE_REF}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Step 1 — Generate SBOM using Syft
echo -e "${YELLOW}Step 1: Generating SBOM with Syft...${NC}"
syft "${IMAGE_REF}" -o cyclonedx-json > sbom-output.cdx.json
echo -e "${GREEN}✅ SBOM generated: sbom-output.cdx.json${NC}"

# Step 2 — Count components
COMPONENT_COUNT=$(jq '.components | length' sbom-output.cdx.json)
echo -e "${BLUE}📦 Total components: ${COMPONENT_COUNT}${NC}"

# Step 3 — Scan for vulnerabilities using Grype
echo -e "${YELLOW}Step 2: Scanning for vulnerabilities with Grype...${NC}"
grype sbom:sbom-output.cdx.json \
  --fail-on critical \
  --output table

if [[ $? -eq 0 ]]; then
  echo -e "${GREEN}✅ No critical vulnerabilities found!${NC}"
else
  echo -e "${RED}❌ Critical vulnerabilities detected — review before deploying!${NC}"
  exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}SBOM analysis complete for: ${IMAGE_REF}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
