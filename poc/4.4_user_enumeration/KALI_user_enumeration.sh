#!/bin/bash

echo "EXISTING USER"
curl -s -X POST http://192.168.200.1:8082/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "4.2@example.com", "password": "ThisIsNotThePassword"}' | jq .

echo "NON-EXISTING USER"
curl -s -X POST http://192.168.200.1:8082/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "fake@email.com", "password": "ThisIsNotThePassword"}' | jq .
