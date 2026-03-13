#!/bin/bash

# login and grab token
TOKEN=$(curl -s -X POST http://192.168.200.1:8082/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "4.5@example.com", "password": "SecureP@ssword6732"}' | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")

echo -e "\n1. Logged in and grabbed token:"
echo $TOKEN

# logout
echo -e "\n2. Trying to log out of account using the token:"
curl -s -X POST http://192.168.200.1:8082/auth/logout \
  -H "Authorization: Bearer $TOKEN" | jq .

# use token after logout
echo -e "\n3. Using token after logout (should fail):"
curl -s http://192.168.200.1:8082/tickets/ \
  -H "Authorization: Bearer $TOKEN" | jq .