import json
import vyper

def compile_vyper_to_json(file_path):
    # Read the contract
    with open(file_path, 'r') as file:
        contract_source_code = file.read()

    # Compile the contract
    compiled_contract = vyper.compile_code(contract_source_code, ['abi', 'bytecode'])

    # Prepare the JSON artifact
    artifact = {
        'contractName': file_path.split('/')[-1].split('.')[0],
        'abi': compiled_contract['abi'],
        'bytecode': compiled_contract['bytecode']
    }

    # Write the artifact to a JSON file
    with open(f"{artifact['contractName']}.json", 'w') as file:
        file.write(json.dumps(artifact, indent=2))

# Compile the contract at 'contracts/MyContract.vy'

compile_vyper_to_json('./contracts/margin-dex/Vault.vy')
compile_vyper_to_json('./contracts/margin-dex/MarginDex.vy')
compile_vyper_to_json('./contracts/margin-dex/SwapRouter.vy')
