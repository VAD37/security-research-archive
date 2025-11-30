#!/bin/bash

# Constants from your latest addresses
PACKAGE_ID="0x9682f4a185de5e73c602839824b26637d12b05212aa1cda2187f2602091875bc"
FARM_ID="0x8ed25e166d68c418ecc718a042fc9a2b4d9c09f7842026656d6003115048190e"
ADMIN_CAP_ID="0x6398fc179f281b37547aeaa16d2f1ccdc6da49544020d7856954e6543d26c2ff"

# Token types from your list
declare -a TOKEN_TYPES=(
    "0x317760d8d13c3995dd65ee8690317a7f016eb91f3df7f2d4a3c7f91f41f3767f::BLUB::BLUB"
    "0x153cbb900bd0931fdef7b5531cbb74ab9b2560ae2e1cc1a4f95bbad2597af0a7::DEEP::DEEP"
    "0x8dbb72c4d5707aba5234b4e481cd6865963b0f3d1bd3af31b748ddeb3cc21085::WBTC::WBTC"
    "0xc92572d0fc18f89136ee47d434be3613ccac92f763901d532ac023b9607bd7b1::ETH::ETH"
    "0x7d5b8d7dd687c74f0d8285689953d0190070058a19e1cc85999626110f0d054c::SUITRUMP::SUITRUMP"
    "0x2::sui::SUI"
    "0xbae81baab068677cc0aad561b1e967d980b0da1d6df6e22d769f8f75417efcbf::NAVX::NAVX"
    "0xe8deb5ceb2301eb5e892f6866658ad28cf2cf9fd3e4b722bdbd19ac2ef882d40::SOL::SOL"
    "0xd063acf810f4617534d8f2d0ce8a9b05accb4da9a6a3e1ccc000a7161c18bf49::CETUS::CETUS"
    "0x907c274c1171f3bfd59f361be215bd23bc5be88b1d1a4816e1caa6c0d61e7fe6::WUSDC::WUSDC"
)

# Function to check if a single asset pool exists
check_single_asset_pool() {
    local token=$1
    
    echo "Checking if single asset pool exists for $token..."
    
    result=$(sui client call --package $PACKAGE_ID --module farm --function get_pool_info \
        --type-args $token \
        --args $FARM_ID \
        --gas-budget 10000000 2>/dev/null)
    
    # Check for active pool in the result (position 4 in the tuple)
    if echo "$result" | grep -q "fields.*active.*true"; then
        echo "Pool exists and is active for $token"
        return 0
    elif echo "$result" | grep -q "fields.*active.*false"; then
        echo "Pool exists but is inactive for $token"
        return 2
    else
        echo "No pool exists for $token"
        return 1
    fi
}

# Function to create single asset pool
create_single_asset_pool() {
    local token=$1
    local allocation_points=$2
    local deposit_fee=$3
    local withdrawal_fee=$4
    local is_native=$5
    
    echo "Creating single asset pool for $token..."
    
    result=$(sui client call --package $PACKAGE_ID --module farm --function create_single_asset_pool \
        --type-args $token \
        --args $FARM_ID "$allocation_points" "$deposit_fee" "$withdrawal_fee" "$is_native" $ADMIN_CAP_ID 0x6 \
        --gas-budget 100000000)
    
    if echo "$result" | grep -q "Error executing transaction"; then
        echo "❌ Failed to create pool for $token"
        return 1
    else
        echo "✅ Successfully created pool for $token"
        return 0
    fi
}

# Main function to create all single asset pools
main() {
    echo "====== Creating Single Asset Pools ======"
    echo

    # Default configuration values
    DEFAULT_ALLOCATION=500  # Allocation points
    DEFAULT_DEPOSIT_FEE=100  # 0.5% in basis points
    DEFAULT_WITHDRAWAL_FEE=100  # 0.5% in basis points
    
    # Special configuration for SUI
    SUI_ALLOCATION=1000  # Higher allocation for SUI
    SUI_IS_NATIVE="true"  # SUI is considered native
    
    # Process each token
    for token in "${TOKEN_TYPES[@]}"; do
        # Get token symbol from type string
        symbol=$(echo "$token" | sed -E 's/.*::([^:]+)::([^:]+)$/\2/')
        
        # Check if pool already exists
        check_single_asset_pool "$token"
        pool_exists=$?
        
        if [ $pool_exists -eq 0 ]; then
            echo "⏩ Skipping $symbol - pool already exists and is active"
        elif [ $pool_exists -eq 2 ]; then
            echo "⚠️ Pool for $symbol exists but is inactive - consider updating pool config"
        else
            echo "🔄 Creating pool for $symbol..."
            
            # Set configuration based on token type
            if [[ "$token" == *"sui::SUI"* ]]; then
                # Special config for SUI
                create_single_asset_pool "$token" "$SUI_ALLOCATION" "$DEFAULT_DEPOSIT_FEE" "$DEFAULT_WITHDRAWAL_FEE" "$SUI_IS_NATIVE"
            else
                # Default config for other tokens
                create_single_asset_pool "$token" "$DEFAULT_ALLOCATION" "$DEFAULT_DEPOSIT_FEE" "$DEFAULT_WITHDRAWAL_FEE" "false"
            fi
            
            # Short delay between transactions to prevent rate limiting
            sleep 2
        fi
        
        echo "----------------------------------------"
    done
    
    echo
    echo "✅ Single asset pool creation process completed!"
}

# Run the main function
main