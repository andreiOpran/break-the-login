#!/bin/bash

# source config from parent directory
source $(dirname "$0")/../config.sh

# generate random email so we don't get db constraint error
TARGET_EMAIL="4.1_$RANDOM@example.com"
TRIVIAL_PASSWORD="12"

# accepts very short or trivial passwords
# no validation at registration
echo "Register account (email $TARGET_EMAIL) with trivial password (password \"$TRIVIAL_PASSWORD\"):"
curl -X POST "$TARGET_IP/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$TARGET_EMAIL\", \"password\": \"$TRIVIAL_PASSWORD\"}" | jq .
