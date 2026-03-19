#!/bin/bash

# source config from parent directory
source $(dirname "$0")/../config.sh

echo -e "\n1. Logging in for the first time (Device A) and grabbing Token A:"
TOKEN_A=$(curl -s -X POST "$TARGET_IP/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email": "4.5@example.com", "password": "SecureP@ssword6732"}' | python3 -c "import sys, json; print(json.load(sys.stdin).get('access_token', ''))")
echo $TOKEN_A

echo -e "\n2. Logging in again (Device B) and grabbing Token B:"
TOKEN_B=$(curl -s -X POST "$TARGET_IP/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email": "4.5@example.com", "password": "SecureP@ssword6732"}' | python3 -c "import sys, json; print(json.load(sys.stdin).get('access_token', ''))")
echo $TOKEN_B

echo -e "\n3. Testing Token B (should succeed):"
HTTP_CODE_B=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET_IP/tickets/" \
  -H "Authorization: Bearer $TOKEN_B")
echo "HTTP Response: $HTTP_CODE_B"

echo -e "\n4. Testing Token A (should fail due to rotation):"
HTTP_CODE_A=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET_IP/tickets/" \
  -H "Authorization: Bearer $TOKEN_A")
echo "HTTP Response: $HTTP_CODE_A"

if [ "$HTTP_CODE_A" == "401" ]; then
    echo -e "\n[SUCCESS] Token Rotation is working -> Token A was invalidated."
    exit 0
else
    echo -e "\n[FAILED] Token Rotation didn't work -> Token A might still be valid."
    exit 1
fi
