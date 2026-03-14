#!/bin/bash

source $(dirname "$0")/config.sh

curl -X POST "$TARGET_IP/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email": "4.2@example.com", "password": "iloveyou"}' | jq .

curl -X POST "$TARGET_IP/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email": "4.3@example.com", "password": "andrew"}' | jq .

curl -X POST "$TARGET_IP/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email": "4.4@example.com", "password": "SecureP@ssword6732"}' | jq .

curl -X POST "$TARGET_IP/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email": "4.5@example.com", "password": "SecureP@ssword6732"}' | jq .

curl -X POST "$TARGET_IP/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email": "4.6@example.com", "password": "SecureP@ssword6732"}' | jq .

curl -X POST "$TARGET_IP/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email": "IDOR.victim@example.com", "password": "SecureP@ssword6732"}' | jq .