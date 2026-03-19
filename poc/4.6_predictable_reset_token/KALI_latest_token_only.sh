#!/bin/bash

# source config from parent directory
source $(dirname "$0")/../config.sh

TARGET_EMAIL="4.6@example.com"
NEW_PASSWORD="NewPassword123!"

echo "1. Requesting FIRST password reset token..."
RESPONSE1=$(curl -s -X 'POST' \
  "$TARGET_IP/auth/forgot-password" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d "{\"email\": \"$TARGET_EMAIL\"}")
TOKEN1=$(echo "$RESPONSE1" | jq -r .reset_token)

if [ "$TOKEN1" == "null" ] || [ -z "$TOKEN1" ]; then
    echo "Failed to get first token: $RESPONSE1"
    exit 1
fi
echo "FIRST token: $TOKEN1"

echo -e "\n2. Requesting SECOND password reset token..."
RESPONSE2=$(curl -s -X 'POST' \
  "$TARGET_IP/auth/forgot-password" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d "{\"email\": \"$TARGET_EMAIL\"}")
TOKEN2=$(echo "$RESPONSE2" | jq -r .reset_token)

if [ "$TOKEN2" == "null" ] || [ -z "$TOKEN2" ]; then
    echo "Failed to get second token: $RESPONSE2"
    exit 1
fi
echo "SECOND token: $TOKEN2"

echo -e "\n3. Attempting to use FIRST (revoked) token..."
RES1=$(curl -s -X POST "$TARGET_IP/auth/reset-password" \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$TOKEN1\", \"new_password\": \"$NEW_PASSWORD\"}")
echo "$RES1" | jq .

echo -e "\n4. Attempting to use SECOND (active) token..."
RES2=$(curl -s -X POST "$TARGET_IP/auth/reset-password" \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$TOKEN2\", \"new_password\": \"$NEW_PASSWORD\"}")
echo "$RES2" | jq .

if echo "$RES1" | grep -q "Invalid token"; then
    echo "[FIXED] First token was revoked"
    exit 0
else
    echo "[VULNERABLE] First token still worked"
    exit 1
fi
