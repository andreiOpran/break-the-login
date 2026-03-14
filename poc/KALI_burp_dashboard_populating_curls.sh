# these curls can be used to populate the burp suite dashboard with the api endpoints,
# by using the proxy as arg, to send to intruder and repeater
source $(dirname "$0")/config.sh

# LOGIN
curl -X POST \
  "$TARGET_IP/auth/login" \
  -H 'Content-Type: application/json' \
  -d '{"email": "user@example.com", "password": "test"}' \
  --proxy 127.0.0.1:8080

# LOGOUT
curl -X POST "$TARGET_IP/auth/logout" \
  -H 'accept: application/json' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwiZW1haWwiOiJ1c2VyQGV4YW1wbGUuY29tIiwicm9sZSI6IkFOQUxZU1QiLCJleHAiOjE3NzM5MTc4Njd9.GkB_4U60R-KRcNglgRkaa7Jw2TlmLXGI-L7npIsH5BQ' \
  --proxy 127.0.0.1:8080

# FORGOT PASSWORD
curl -X 'POST' \
  "$TARGET_IP/auth/forgot-password" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{"email": "user@example.com"}' \
  --proxy 127.0.0.1:8080

# RESET PASSWORD
curl -X 'POST' \
  "$TARGET_IP/auth/reset-password" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{"token": "b58996c504c5638798eb6b511e6f49af", "new_password": "andrew1"}' \
  --proxy 127.0.0.1:8080

# GET TICKETS
curl -X 'GET' \
  "$TARGET_IP/tickets/" \
  -H 'accept: application/json' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwiZW1haWwiOiJ1c2VyQGV4YW1wbGUuY29tIiwicm9sZSI6IkFOQUxZU1QiLCJleHAiOjE3NzQwMTMxNjN9.EuRxqj5Ii5h1nVrJiOpVjACiLLg7TFismLzeUI5qmG4' \
  --proxy 127.0.0.1:8080

# CREATE TICKET
curl -X 'POST' \
  "$TARGET_IP/tickets/" \
  -H 'accept: application/json' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwiZW1haWwiOiJ1c2VyQGV4YW1wbGUuY29tIiwicm9sZSI6IkFOQUxZU1QiLCJleHAiOjE3NzQwMTMxNjN9.EuRxqj5Ii5h1nVrJiOpVjACiLLg7TFismLzeUI5qmG4' \
  -H 'Content-Type: application/json' \
  -d '{"title": "string","description": "string","severity": "LOW"}' \
  --proxy 127.0.0.1:8080