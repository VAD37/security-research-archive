#!/bin/bash

# Constants from your latest addresses
PACKAGE_ID="0x9682f4a185de5e73c602839824b26637d12b05212aa1cda2187f2602091875bc"
FARM_ID="0x8ed25e166d68c418ecc718a042fc9a2b4d9c09f7842026656d6003115048190e"
ADMIN_CAP_ID="0x6398fc179f281b37547aeaa16d2f1ccdc6da49544020d7856954e6543d26c2ff"

# Define LP pairs to create
# Format: "CoinTypeA CoinTypeB IsNativePair Allocation"
declare -a LP_PAIRS=(
    "0x2::sui::SUI 0x8dbb72c4d5707aba5234b4e481cd6865963b0f3d1bd3af31b748ddeb3cc21085::WBTC::WBTC true 1500"
    "0x2::sui::SUI 0xc92572d0fc18f89136ee47d434be3613ccac92f763901d532ac023b9607bd7b1::ETH::ETH true 1500"
    "0x2::sui::SUI 0x907c274c1171f3bfd59f361be215bd23bc5be88b1d1a4816e1caa6c0d61e7fe6::WUSDC::WUSDC true 1500"
    "0x2::sui::SUI 0x7d5b8d7dd687c74f0d8285689953d0190070058a19e1cc85999626110f0d054c::SUITRUMP::SUITRUMP true 1500"
    "0xc92572d0fc18f89136ee47d434be3613ccac92f763901d532ac023b9607bd7b1::ETH::ETH 0x8dbb72c4d5707aba5234b4e481cd6865963b0f3d1bd3af31b748ddeb3cc21085::WBTC::WBTC false 800"
    "0x907c274c1171f3bfd59f361be215bd23bc5be88b1d1a4816e1caa6c0d61e7fe6::WUSDC::WUSDC 0x8dbb72c4d5707aba5234b4e481cd6865963b0f3d1bd3af31b748ddeb3cc21085::WBTC::WBTC false 800"
)

# Default fee configuration
DEFAULT_DEPOSIT_FEE=100     # 1% in basis points
DEFAULT_WITHDRAWAL_FEE=100  # 1% in basis points

# Function to check if an LP pool exists
check_lp_pool() {
    local coin_type_a=$1
    local coin_type_b=$2
    
    echo "Checking if LP pool exists for $coin_type_a and $coin_type_b..."
    
    # Get symbol names for cleaner output
    symbol_a=$(echo "$coin_type_a" | sed -E 's/.*::([^:]+)::([^:]+)$/\2/')
    symbol_b=$(echo "$coin_type_b" | sed -E 's/.*::([^:]+)::([^:]+)$/\2/')
    
    # Call the get_pool_info function with LP type
    result=$(sui client call --package $PACKAGE_ID --module farm --function get_pool_info \
        --type-args "0x$PACKAGE_ID::pair::LPCoin<$coin_type_a, $coin_type_b>" \
        --args $FARM_ID \
        --gas-budget 10000000 2>/dev/null)
    
    # Check for active pool in the result
    if echo "$result" | grep -q "fields.*active.*true"; then
        echo "Pool exists and is active for $symbol_a-$symbol_b LP"
        return 0
    elif echo "$result" | grep -q "fields.*active.*false"; then
        echo "Pool exists but is inactive for $symbol_a-$symbol_b LP"
        return 2
    else
        echo "No pool exists for $symbol_a-$symbol_b LP"
        return 1
    fi
}

# Function to create LP pool
create_lp_pool() {
    local coin_type_a=$1
    local coin_type_b=$2
    local is_native_pair=$3
    local allocation_points=$4
    local deposit_fee=$5
    local withdrawal_fee=$6
    
    # Get symbol names for cleaner output
    symbol_a=$(echo "$coin_type_a" | sed -E 's/.*::([^:]+)::([^:]+)$/\2/')
    symbol_b=$(echo "$coin_type_b" | sed -E 's/.*::([^:]+)::([^:]+)$/\2/')
    
    echo "Creating LP pool for $symbol_a-$symbol_b..."
    
    # Call the create_lp_pool function
    result=$(sui client call --package $PACKAGE_ID --module farm --function create_lp_pool \
        --type-args "$coin_type_a" "$coin_type_b" \
        --args $FARM_ID "$allocation_points" "$deposit_fee" "$withdrawal_fee" "$is_native_pair" $ADMIN_CAP_ID 0x6 \
        --gas-budget 100000000)
    
    if echo "$result" | grep -q "Error executing transaction"; then
        echo "❌ Failed to create LP pool for $symbol_a-$symbol_b"
        echo "$result" | grep -A 10 "Error executing transaction"
        return 1
    else
        echo "✅ Successfully created LP pool for $symbol_a-$symbol_b"
        return 0
    fi
}

# Note: We don't need a separate allow_lp_type function
# The create_lp_pool function automatically adds the LP type to the allowed list

# Main function to create all LP pools
main() {
    echo "====== Creating LP Pools ======"
    echo
    
    # Process each LP pair
    for pair in "${LP_PAIRS[@]}"; do
        # Split the pair info
        read -r coin_type_a coin_type_b is_native_pair allocation_points <<< "$pair"
        
        # Check if pool already exists
        check_lp_pool "$coin_type_a" "$coin_type_b"
        pool_exists=$?
        
        if [ $pool_exists -eq 0 ]; then
            echo "⏩ Skipping - pool already exists and is active"
        elif [ $pool_exists -eq 2 ]; then
            echo "⚠️ Pool exists but is inactive - consider updating pool config"
        else
            echo "🔄 Creating pool..."
            
            # Create the pool (this also allows the LP type automatically)
            create_lp_pool "$coin_type_a" "$coin_type_b" "$is_native_pair" "$allocation_points" "$DEFAULT_DEPOSIT_FEE" "$DEFAULT_WITHDRAWAL_FEE"
            
            # Short delay between transactions to prevent rate limiting
            sleep 2
        fi
        
        echo "----------------------------------------"
    done
    
    echo
    echo "✅ LP pool creation process completed!"
}

# Run the main function
main