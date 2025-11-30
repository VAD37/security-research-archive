#!/usr/bin/env bash
# rerun_forge.sh — Run “forge script RunScript” 500 times
# fail fast
set -o errexit
set -o nounset
set -o pipefail

# if there's a .env file in cwd, export its vars
if [[ -f .env ]]; then
  # ignore blank lines and lines starting with #
  export $(grep -vE '^\s*#' .env | xargs)
fi

# Make sure ETH_RPC_URL is set
if [[ -z "$ETH_RPC_URL" ]]; then
  echo "Error: ETH_RPC_URL is not defined."
  exit 1
fi

for i in $(seq 1 500); do
  echo ">>> Iteration $i/500"
  forge script RunScript \
    --fork-url "$ETH_RPC_URL" \
    --broadcast \
    --gas-estimate-multiplier 1000

  # Optional: pause between runs to avoid rate‐limits or RPC throttling
  # sleep 1
done

echo "All 500 runs complete."
