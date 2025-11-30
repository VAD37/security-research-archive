build:
	sui move build

test:
	sui move test

deploy-program:
	sui client publish --gas-budget 1000000000

update-program:
	sui client upgrade --gas-budget 500000000 --upgrade-capability 0xfc0f81848a4e0d80fcc1f6e90bf9eeeb5d1f85656233f336d581731037577af2

configure-devnet:
	sui client envs && sui client switch --env devnet

configure-testnet:
	sui client envs && sui client switch --env testnet

request-faucet-to-reciever:
	sui client faucet --address 0xc17889dee9255f80462972cd1218165c3a16e37d5242aa4c2070af4f46cebb01

request-faucet:
	sui client faucet

set-testnet-network:
	sui client new-env --alias testnet --rpc https://fullnode.testnet.sui.io:443

check-gas:
	sui client gas