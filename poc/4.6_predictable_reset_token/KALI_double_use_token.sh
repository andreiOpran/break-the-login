#!/bin/bash

# source config from parent directory
source $(dirname "$0")/../config.sh

TARGET_EMAIL="4.6@example.com"
NEW_PASSWORD="NewPassword123!"

echo "1. Requesting password reset token..."
RESPONSE=$(curl -s -X 'POST' \
  "$TARGET_IP/auth/forgot-password" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d "{\"email\": \"$TARGET_EMAIL\"}")
TOKEN=$(echo "$RESPONSE" | jq -r .reset_token)

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
    echo "Failed to get token: $RESPONSE"
    exit 1
fi
echo "Token: $TOKEN"

echo -e "\n2. Performing first password reset..."
curl -s -X POST "$TARGET_IP/auth/reset-password" \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$TOKEN\", \"new_password\": \"$NEW_PASSWORD\"}" | jq .

echo -e "\n3. Performing second password reset with same token..."
RES=$(curl -s -X POST "$TARGET_IP/auth/reset-password" \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$TOKEN\", \"new_password\": \"${NEW_PASSWORD}Diff!\"}")

echo "$RES" | jq .

if echo "$RES" | grep -q "Invalid token"; then
    echo "[FIXED] Double use prevented"
    exit 0
else
    echo "[VULNERABLE] Double use allowed"
    exit 1
fi
