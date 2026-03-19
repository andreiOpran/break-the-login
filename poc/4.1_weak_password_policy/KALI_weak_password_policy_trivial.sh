#!/bin/bash

# source config from parent directory
source $(dirname "$0")/../config.sh

# generate random email so we don't get db constraint error
TARGET_EMAIL="4.1_$RANDOM@example.com"
TRIVIAL_PASSWORD="12"

# accepts very short or trivial passwords
# no validation at registration
echo "Register account (email $TARGET_EMAIL) with trivial password (password \"$TRIVIAL_PASSWORD\"):"
RESPONSE=$(curl -s -X POST "$TARGET_IP/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$TARGET_EMAIL\", \"password\": \"$TRIVIAL_PASSWORD\"}")

echo "$RESPONSE" | jq .

if echo "$RESPONSE" | grep -q 'message'; then
  # success message means vulnerability exists (bad password accepted)
  exit 1
elif echo "$RESPONSE" | grep -q 'detail'; then
  # validation error (like "Password must be at least 8...") means it's fixed
  exit 0
else
  exit 1
fi
