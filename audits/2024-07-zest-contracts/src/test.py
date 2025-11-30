import webbrowser
import requests

# smart_contracts = []

# # url = "https://api.mainnet.hiro.so/extended/v1/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N/mempool"

# urls =[
#    "https://api.mainnet.hiro.so/extended/v2/addresses/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N/transactions?limit=50&offset=0",
#    "https://api.mainnet.hiro.so/extended/v2/addresses/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N/transactions?limit=50&offset=50",
#    "https://api.mainnet.hiro.so/extended/v2/addresses/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N/transactions?limit=50&offset=100"
# ]
# payload = {}
# headers = {
#   'Accept': 'application/json'
# }

# for url in urls:   
#   response = requests.request("GET", url, headers=headers, data=payload)
#   json_response = response.json()
#   for tx in json_response['results']:
#       _tx = tx['tx']
#       # print(_tx["tx_type"])
#       if _tx["tx_type"] == "smart_contract":
#         smart_contracts.append(_tx["smart_contract"]["contract_id"])

# # print sorted in new line each
# for sc in sorted(smart_contracts):
#   print(sc)

addresses = [    
"SP2A8GZ4JQ10D52CJ34MWHN05EQDRK5DQZT7SCM5E.nothing",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.a-token-trait",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.aeusdc-oracle-v1-0",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.assets-deployed-1",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.assets-deployed-1",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v1-0",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v1-0",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v1-1",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v1-1",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v2-0",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v2-1",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v2-2",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.flash-loan-trait",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ft-mint-trait",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ft-trait",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.liquidation-manager",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.liquidation-manager-v1-1",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.lp-token-trait",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.math",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.oracle-trait",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ownable-trait",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-borrow",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-borrow-v1-1",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-liquidation",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-liquidation-v1-0",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-liquidation-v1-1",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-liquidation-v1-2",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-liquidation-v1-3",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-supply",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-supply-v1-0",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-supply-v1-1",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-supply-v1-2",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-supply-v1-2",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-supply-v1-2",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-v1-0",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-v1-2",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-v1-2",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-reserve-data",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-vault",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.redeemeable-trait",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.redeemeable-trait-v1-0",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.redeemeable-trait-v1-1",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.run-1",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.run-2",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.run-3",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.run-4",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.run-5",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ststx-aeusdc-deployment",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ststx-oracle",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ststx-oracle-v1-0",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ststx-oracle-v1-1",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ststx-oracle-v1-2",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ststx-oracle-v1-3",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ststx-oracle-v1-3",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-oracle",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-oracle-v1-0",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-oracle-v1-1",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-oracle-v1-2",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-oracle-v1-3",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.supply-wrapped",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-1",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-10",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-11",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-12",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-aeusdc",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-aeusdc-2",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-aeusdc-rate",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-helper-1",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-ststx-1",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-ststx-oracle",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-wstx",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-wstx-1",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-wstx-2",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-wstx-3",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.vault-trait",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.wstx",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.wstx-deployment",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zaeusdc",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zaeusdc-v1-0",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zest-borrow-helper",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zststx",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zststx-v1-0",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zwstx",
"SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zwstx-v1",
"SP3FDZ98RZZ67SDNSCXT4TQAYHWCAH0H37K2V153F.airdrop",
"SP3SJSNPJXXHY7RJM48ZT6G1BXYZADAC5YAXZA3ZC.cognitive-bronze-vole",
"SPBNMD07T0WD2WJAH6JZJG07GYSF0X413V69J3T9.Ponzy-Gold11-Stacks",
"SPXZB55NWTRQM02QYK7Z6K2PP7F279F640HAYTPG.airdrop122",
]

# craft into URL https://explorer.hiro.so/txid/0x8d105a226b4ae1fc8d3f2e238353120fa2096328d3604003dfb046f49f8acdd6?chain=mainnet
for address in addresses:
  print(f"https://explorer.hiro.so/address/{address}?chain=mainnet")
  #open URL in browser
  webbrowser.open(f"https://explorer.hiro.so/address/{address}?chain=mainnet")
# https://explorer.hiro.so/address/SP2A8GZ4JQ10D52CJ34MWHN05EQDRK5DQZT7SCM5E.nothing?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.a-token-trait?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.aeusdc-oracle-v1-0?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.assets-deployed-1?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.assets-deployed-1?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v1-0?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v1-0?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v1-1?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v1-1?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v2-0?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v2-1?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.borrow-helper-v2-2?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.flash-loan-trait?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ft-mint-trait?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ft-trait?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.liquidation-manager?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.liquidation-manager-v1-1?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.lp-token-trait?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.math?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.oracle-trait?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ownable-trait?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-0-reserve?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-borrow?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-borrow-v1-1?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-liquidation?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-liquidation-v1-0?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-liquidation-v1-1?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-liquidation-v1-2?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-liquidation-v1-3?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-supply?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-supply-v1-0?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-supply-v1-1?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-supply-v1-2?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-supply-v1-2?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-supply-v1-2?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-v1-0?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-v1-2?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-read-v1-2?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-reserve-data?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.pool-vault?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.redeemeable-trait?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.redeemeable-trait-v1-0?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.redeemeable-trait-v1-1?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.run-1?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.run-2?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.run-3?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.run-4?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.run-5?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ststx-aeusdc-deployment?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ststx-oracle?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ststx-oracle-v1-0?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ststx-oracle-v1-1?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ststx-oracle-v1-2?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ststx-oracle-v1-3?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.ststx-oracle-v1-3?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-oracle?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-oracle-v1-0?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-oracle-v1-1?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-oracle-v1-2?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.stx-oracle-v1-3?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.supply-wrapped?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-1?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-10?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-11?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-12?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-aeusdc?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-aeusdc-2?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-aeusdc-rate?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-helper-1?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-ststx-1?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-ststx-oracle?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-wstx?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-wstx-1?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-wstx-2?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.update-wstx-3?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.vault-trait?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.wstx?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.wstx-deployment?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zaeusdc?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zaeusdc-v1-0?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zest-borrow-helper?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zststx?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zststx-v1-0?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zwstx?chain=mainnet
# https://explorer.hiro.so/address/SP2VCQJGH7PHP2DJK7Z0V48AGBHQAW3R3ZW1QF4N.zwstx-v1?chain=mainnet
# https://explorer.hiro.so/address/SP3FDZ98RZZ67SDNSCXT4TQAYHWCAH0H37K2V153F.airdrop?chain=mainnet
# https://explorer.hiro.so/address/SP3SJSNPJXXHY7RJM48ZT6G1BXYZADAC5YAXZA3ZC.cognitive-bronze-vole?chain=mainnet
# https://explorer.hiro.so/address/SPBNMD07T0WD2WJAH6JZJG07GYSF0X413V69J3T9.Ponzy-Gold11-Stacks?chain=mainnet
# https://explorer.hiro.so/address/SPXZB55NWTRQM02QYK7Z6K2PP7F279F640HAYTPG.airdrop122?chain=mainnet