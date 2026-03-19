#!/bin/bash

# source config from parent directory
source $(dirname "$0")/../config.sh

# login and grab token
TOKEN=$(curl -s -X POST "$TARGET_IP/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email": "4.5@example.com", "password": "SecureP@ssword6732"}' | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")

echo -e "\n1. Logged in and grabbed token:"
echo $TOKEN

if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ] || [ "$TOKEN" == "None" ]; then
    echo "Failed to get token. Exiting."
    exit 1
fi

# logout
echo -e "\n2. Trying to log out of account using the token:"
curl -s -X POST "$TARGET_IP/auth/logout" \
  -H "Authorization: Bearer $TOKEN" | jq .

# use token after logout
echo -e "\n3. Using token after logout (should fail):"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET_IP/tickets/" \
  -H "Authorization: Bearer $TOKEN")

if [ "$HTTP_CODE" == "200" ]; then
    echo "Response: HTTP 200 OK"
    echo "[VULNERABLE] Token was NOT invalidated after logout."
    exit 1
else
    echo "Response: HTTP $HTTP_CODE"
    echo "[FIXED] Token was successfully invalidated."
    exit 0
fi