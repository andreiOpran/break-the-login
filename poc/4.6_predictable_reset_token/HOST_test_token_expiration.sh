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

echo -e "\n2. Modifying database to forcefully make token be expired, by modifying expiration date..."
DB_PATH="$(dirname "$0")/../../authx.db"
if [ ! -f "$DB_PATH" ]; then
    echo "Could not find authx.db at $DB_PATH"
    exit 1
fi
sqlite3 "$DB_PATH" "UPDATE password_reset_tokens SET created_at = datetime(created_at, '-120 minutes') WHERE token = '$TOKEN';"
echo "Token forcefully expired in "

echo -e "\n3. Attempting to use expired token..."
RES=$(curl -s -X POST \
  "$TARGET_IP/auth/reset-password" \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$TOKEN\", \"new_password\": \"$NEW_PASSWORD\"}")

echo "$RES" | jq .

if echo "$RES" | grep -q "Token has expired"; then
    echo "[FIXED] Token expiration enforced"
    exit 0
else
    echo "[VULNERABLE] Expired token accepted"
    exit 1
fi
