#!/bin/bash
# chmod +x /home/andrei/Desktop/break-the-login/run.sh

if [ ! -d ".venv" ]; then
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
fi

source .venv/bin/activate

.venv/bin/uvicorn app.main:app --reload --port 8082
