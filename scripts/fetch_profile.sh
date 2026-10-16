#!/usr/bin/env bash
set -euo pipefail

TOKEN="${1:-${UPLOAD_AM_TOKEN:-}}"
OUTPUT="${2:-profile.ovpn}"

if [ -z "$TOKEN" ]; then
    echo "Usage: $0 <UPLOAD_AM_API_TOKEN> [output.ovpn]"
    echo "Or set UPLOAD_AM_TOKEN environment variable."
    exit 1
fi

echo "Fetching OpenVPN profile from upload.am API..."
HTTP_CODE=$(curl -sSL -w "%{http_code}" -o "$OUTPUT" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json" \
    "https://upload.am/api/v1/vpn/profile")

if [ "$HTTP_CODE" -ne 200 ]; then
    echo "Error: API returned HTTP $HTTP_CODE"
    cat "$OUTPUT"
    rm -f "$OUTPUT"
    exit 1
fi

echo "Successfully saved OpenVPN profile to $OUTPUT"
