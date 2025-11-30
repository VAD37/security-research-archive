#!/bin/bash

. ./.env

IMAGE="gcr.io/paradigm-ctf/2022/$1:latest"
# If $2 is empty or unset, default to 31337
PORT="${2:-31337}"
HTTP_PORT="${3:-8545}"

echo $ETH_RPC_URL

echo "[+] running challenge"
exec docker run \
    -e "PORT=$PORT" \
    -e "HTTP_PORT=$HTTP_PORT" \
    -e "ETH_RPC_URL=$ETH_RPC_URL" \
    -e "FLAG=PCTF{flag}" \
    -p "$PORT:$PORT" \
    -p "$HTTP_PORT:$HTTP_PORT" \
    "$IMAGE"