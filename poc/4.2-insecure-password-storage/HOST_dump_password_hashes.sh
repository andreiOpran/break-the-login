#!/bin/bash

sqlite3 ../../authx.db "SELECT email, password_hash FROM users WHERE email='4.2@example.com';"
