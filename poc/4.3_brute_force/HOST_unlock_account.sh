#!/bin/bash

TARGET_EMAIL="4.3@example.com"

sqlite3 ../../authx.db "UPDATE users SET locked = 0 WHERE email = '$TARGET_EMAIL';"
sqlite3 ../../authx.db "DELETE FROM audit_logs WHERE action = 'LOGIN_FAILED' AND user_id = (SELECT id FROM users WHERE email = '$TARGET_EMAIL');"