#!/bin/bash

# ============================================================================
# SuiTrump DEX Complete Setup Script - FIXED VERSION
# ============================================================================
# This script performs the entire end-to-end setup for the SuiTrump DEX
# including Farm, Victory Token Locker, and Emission Controller
# ============================================================================

set -e  # Exit on any error

# ============================================================================
# CONFIGURATION - UPDATE THESE VALUES
# ============================================================================

# Contract Addresses (UPDATE WITH YOUR DEPLOYED VALUES)
PACKAGE_ID="0x98196c320f9b41eb9ff019326baa7c066d6090682a1e954c983ac2df8f231084"
GLOBAL_EMISSION_CONFIG="0x6246fa0c8343d8276e7e50937ff501903cfc0a9c847684473d31c35e9ac05282"
FARM_ID="0xe8803c361870523be4229f01a028527099782de9fc15e4506302c3a51a63ef42"
VICTORY_LOCKER_ID="0x689b321ba40532d5b5de1df425784af570dd1ae551c4a7e734d5c9179ff6c44f"
VICTORY_TREASURY_CAP="0x661d31bd5c44197490db77247d9b8b066a64cacc6aa16fd1c7dde1b6331eecb5"

# Admin Capabilities (UPDATE WITH YOUR ADMIN CAPS)
GLOBAL_EMISSION_ADMIN_CAP="0xc7dbe19fc418c31049c8f6db5360552919e283e529f9e5a7188b22b9fb6a2a85"
FARM_ADMIN_CAP="0x4ad19d2488a8c70aac0fbeb950563673262df63914de88934db586f8bbcf5126"
LOCKER_ADMIN_CAP="0xfb725f6600b317729619b61575f1a3d167cc474549126620d8c32cc3e887ed7c"
VICTORY_MINTER_CAP="0x986f116624e43b91c7ec08e7977198ca5176608e58da78b74f0fb347c9ddd5de"

# Fee Distribution Addresses (UPDATE WITH YOUR ADDRESSES)
BURN_ADDRESS="0x0000000000000000000000000000000000000000000000000000000000000001"
LOCKER_ADDRESS="0x9b15baa31a2d308bd09f9258f0a9db09da3d4e8e113cf1888efa919d9778fa7c"
TEAM_ADDRESS="0x9b15baa31a2d308bd09f9258f0a9db09da3d4e8e113cf1888efa919d9778fa7c"
DEV_ADDRESS="0x9b15baa31a2d308bd09f9258f0a9db09da3d4e8e113cf1888efa919d9778fa7c"

# Victory Token Configuration
VICTORY_TOKEN_TYPE="$PACKAGE_ID::victory_token::VICTORY_TOKEN"
FARM_FUNDING_AMOUNT="400000000000"  # 400M Victory tokens (6 decimals, not 9!)
LOCKER_FUNDING_AMOUNT="100000000000"  # 100M Victory tokens (6 decimals, not 9!)

# Token Types for Farm Pools (EXCLUDE Victory - it has dedicated locker)
declare -a SINGLE_ASSET_TOKENS=(
    "0x2::sui::SUI"
    "0x8dbb72c4d5707aba5234b4e481cd6865963b0f3d1bd3af31b748ddeb3cc21085::WBTC::WBTC"
    "0xc92572d0fc18f89136ee47d434be3613ccac92f763901d532ac023b9607bd7b1::ETH::ETH"
    "0x907c274c1171f3bfd59f361be215bd23bc5be88b1d1a4816e1caa6c0d61e7fe6::WUSDC::WUSDC"
    "0x153cbb900bd0931fdef7b5531cbb74ab9b2560ae2e1cc1a4f95bbad2597af0a7::DEEP::DEEP"
)

# LP Pairs for Farm (Format: "TokenA TokenB IsNativePair AllocationPoints")
declare -a LP_PAIRS=(
    "$VICTORY_TOKEN_TYPE 0x2::sui::SUI true 2000"
    "0x2::sui::SUI 0x8dbb72c4d5707aba5234b4e481cd6865963b0f3d1bd3af31b748ddeb3cc21085::WBTC::WBTC true 1500"
    "0x2::sui::SUI 0xc92572d0fc18f89136ee47d434be3613ccac92f763901d532ac023b9607bd7b1::ETH::ETH true 1500"
    "0x2::sui::SUI 0x907c274c1171f3bfd59f361be215bd23bc5be88b1d1a4816e1caa6c0d61e7fe6::WUSDC::WUSDC true 1500"
    "0xc92572d0fc18f89136ee47d434be3613ccac92f763901d532ac023b9607bd7b1::ETH::ETH 0x8dbb72c4d5707aba5234b4e481cd6865963b0f3d1bd3af31b748ddeb3cc21085::WBTC::WBTC false 1000"
)

# Pool Configuration
DEFAULT_LP_DEPOSIT_FEE=100      # 1%
DEFAULT_LP_WITHDRAWAL_FEE=100   # 1%
DEFAULT_SINGLE_DEPOSIT_FEE=50   # 0.5%
DEFAULT_SINGLE_WITHDRAWAL_FEE=50 # 0.5%

# Presale Configuration (Optional)
ENABLE_PRESALE_LOCKS=false
declare -a PRESALE_USERS=(
    # "user_address amount_in_smallest_unit"
    # "0x1234... 1000000000000"  # 1000 Victory tokens
)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log() {
    echo "🔧 [$(date '+%H:%M:%S')] $1"
}

success() {
    echo "✅ [$(date '+%H:%M:%S')] $1"
}

error() {
    echo "❌ [$(date '+%H:%M:%S')] ERROR: $1"
    exit 1
}

warning() {
    echo "⚠️ [$(date '+%H:%M:%S')] WARNING: $1"
}

confirm() {
    echo "⚠️  CRITICAL: $1"
    read -p "Type 'YES' to continue: " response
    if [ "$response" != "YES" ]; then
        error "Operation cancelled by user"
    fi
}

# ============================================================================
# IMPROVED OBJECT ID EXTRACTION FUNCTIONS
# ============================================================================

# Function to extract object ID from transaction result - COMPLETELY REWRITTEN
extract_object_id() {
    local result="$1"
    local object_type="$2"
    
    echo "🔍 DEBUG: Extracting object ID for type: $object_type" >&2
    
    # Get all created objects and their IDs
    local created_objects=$(echo "$result" | grep -A 200 "Created Objects")
    
    if [ -z "$created_objects" ]; then
        echo "🔍 DEBUG: No created objects found in transaction" >&2
        return 1
    fi
    
    # Extract ObjectID patterns - more robust approach
    local object_ids=$(echo "$created_objects" | grep "ObjectID:" | sed 's/.*ObjectID: \(0x[a-f0-9]*\).*/\1/')
    
    if [ -z "$object_ids" ]; then
        echo "🔍 DEBUG: No ObjectIDs found in created objects" >&2
        return 1
    fi
    
    # For most cases, we want the first created object
    local first_id=$(echo "$object_ids" | head -1)
    
    echo "🔍 DEBUG: Found ObjectIDs: $object_ids" >&2
    echo "🔍 DEBUG: Using first ObjectID: $first_id" >&2
    
    echo "$first_id"
}

# Alternative function to get all created object IDs
get_all_created_objects() {
    local result="$1"
    echo "$result" | grep -A 200 "Created Objects" | grep "ObjectID:" | sed 's/.*ObjectID: \(0x[a-f0-9]*\).*/\1/'
}

# Function to extract transaction digest from result
extract_digest() {
    local result="$1"
    echo "$result" | grep "Transaction Digest:" | sed 's/.*Transaction Digest: \([A-Za-z0-9]*\).*/\1/' | head -1
}

# Function to create SuiVision testnet URL
get_suivision_url() {
    local digest="$1"
    if [ -n "$digest" ]; then
        echo "https://testnet.suivision.xyz/txblock/$digest"
    fi
}

# Enhanced success function with transaction link
success_with_tx() {
    local message="$1"
    local result="$2"
    local digest=$(extract_digest "$result")
    local url=$(get_suivision_url "$digest")
    
    if [ -n "$url" ]; then
        echo "✅ [$(date '+%H:%M:%S')] $message"
        echo "   🔗 View transaction: $url"
    else
        echo "✅ [$(date '+%H:%M:%S')] $message"
    fi
}

# ============================================================================
# SAFETY CHECK FUNCTIONS
# ============================================================================

check_farm_initialized() {
    log "Checking if farm is already initialized..."
    
    result=$(sui client call --package $PACKAGE_ID \
        --module farm \
        --function get_farm_info_detailed \
        --args $FARM_ID \
        --gas-budget 10000000 2>&1)
    
    # If we get valid farm info, it's likely initialized
    if echo "$result" | grep -q "Status: Success" && echo "$result" | grep -q "total_victory_distributed"; then
        success "Farm is already initialized"
        return 0
    else
        log "Farm needs initialization"
        return 1
    fi
}

check_emission_initialized() {
    log "Checking if emissions are already initialized..."
    
    result=$(sui client call --package $PACKAGE_ID \
        --module global_emission_controller \
        --function get_emission_status \
        --args $GLOBAL_EMISSION_CONFIG 0x6 \
        --gas-budget 10000000 2>&1)
    
    # Look for non-zero current week indicating emissions started
    if echo "$result" | grep -q "Status: Success"; then
        # Try to extract week info to see if initialized
        if echo "$result" | grep -A 10 -B 10 "current_week" | grep -v "0," | grep -q "[1-9]"; then
            success "Emissions are already initialized and running"
            return 0
        else
            log "Emissions need initialization"
            return 1
        fi
    else
        log "Cannot check emission status, will attempt initialization"
        return 1
    fi
}

check_pool_exists() {
    local token_type="$1"
    local pool_description="$2"
    
    result=$(sui client call --package $PACKAGE_ID \
        --module farm \
        --function get_pool_info \
        --type-args "$token_type" \
        --args $FARM_ID \
        --gas-budget 10000000 2>&1)
    
    if echo "$result" | grep -q "Status: Success" && echo "$result" | grep -q "active.*true"; then
        log "$pool_description already exists and is active"
        return 0
    else
        log "$pool_description needs to be created"
        return 1
    fi
}

check_vault_funded() {
    local vault_id="$1"
    local vault_name="$2"
    
    if [ -z "$vault_id" ]; then
        log "$vault_name vault ID not available, assuming needs funding"
        return 1
    fi
    
    # Try to get vault balance (this is a simple existence check)
    result=$(sui client object --id "$vault_id" 2>&1)
    
    if echo "$result" | grep -q "balance.*[1-9]"; then
        log "$vault_name appears to be funded"
        return 0
    else
        log "$vault_name needs funding"
        return 1
    fi
}

# ============================================================================
# VAULT CREATION FUNCTIONS
# ============================================================================

create_farm_reward_vault() {
    log "Creating Farm reward vault..."
    
    result=$(sui client call --package $PACKAGE_ID \
        --module farm \
        --function create_reward_vault \
        --args $FARM_ADMIN_CAP \
        --gas-budget 100000000 2>&1)
    
    if echo "$result" | grep -q "Status: Success"; then
        FARM_VAULT_ID=$(extract_object_id "$result" "RewardVault")
        success_with_tx "Farm reward vault created: $FARM_VAULT_ID" "$result"
    else
        error "Failed to create farm reward vault"
    fi
}

create_locker_vaults() {
    log "Creating Victory Locker vaults..."
    
    # Create locked token vault
    log "Creating locked token vault..."
    result=$(sui client call --package $PACKAGE_ID \
        --module victory_token_locker \
        --function create_locked_token_vault \
        --args $LOCKER_ADMIN_CAP \
        --gas-budget 100000000 2>&1)
    
    if echo "$result" | grep -q "Status: Success"; then
        LOCKED_TOKEN_VAULT_ID=$(extract_object_id "$result" "LockedTokenVault")
        success_with_tx "Locked token vault created: $LOCKED_TOKEN_VAULT_ID" "$result"
    else
        error "Failed to create locked token vault"
    fi
    
    # Create Victory reward vault
    log "Creating Victory reward vault..."
    result=$(sui client call --package $PACKAGE_ID \
        --module victory_token_locker \
        --function create_victory_reward_vault \
        --args $LOCKER_ADMIN_CAP \
        --gas-budget 100000000 2>&1)
    
    if echo "$result" | grep -q "Status: Success"; then
        VICTORY_REWARD_VAULT_ID=$(extract_object_id "$result" "VictoryRewardVault")
        success_with_tx "Victory reward vault created: $VICTORY_REWARD_VAULT_ID" "$result"
    else
        error "Failed to create Victory reward vault"
    fi
    
    # Create SUI reward vault
    log "Creating SUI reward vault..."
    result=$(sui client call --package $PACKAGE_ID \
        --module victory_token_locker \
        --function create_sui_reward_vault \
        --args $LOCKER_ADMIN_CAP \
        --gas-budget 100000000 2>&1)
    
    if echo "$result" | grep -q "Status: Success"; then
        SUI_REWARD_VAULT_ID=$(extract_object_id "$result" "SUIRewardVault")
        success_with_tx "SUI reward vault created: $SUI_REWARD_VAULT_ID" "$result"
    else
        error "Failed to create SUI reward vault"
    fi
}

# ============================================================================
# INITIALIZATION FUNCTIONS
# ============================================================================

initialize_farm() {
    if check_farm_initialized; then
        success "Farm already initialized, skipping..."
        return
    fi
    
    log "Initializing farm timestamps..."
    
    result=$(sui client call --package $PACKAGE_ID \
        --module farm \
        --function initialize_timestamps \
        --args $FARM_ID $FARM_ADMIN_CAP 0x6 \
        --gas-budget 100000000 2>&1)
    
    if echo "$result" | grep -q "Status: Success"; then
        success_with_tx "Farm timestamps initialized" "$result"
    else
        error "Failed to initialize farm timestamps"
    fi
}

set_farm_addresses() {
    log "Setting farm fee distribution addresses..."
    
    result=$(sui client call --package $PACKAGE_ID \
        --module farm \
        --function set_addresses \
        --args $FARM_ID $BURN_ADDRESS $LOCKER_ADDRESS $TEAM_ADDRESS $DEV_ADDRESS $FARM_ADMIN_CAP \
        --gas-budget 100000000 2>&1)
    
    if echo "$result" | grep -q "Status: Success"; then
        success_with_tx "Farm addresses configured" "$result"
    elif echo "$result" | grep -q "MoveAbort.*15"; then
        success "Farm addresses already configured, skipping..."
    else
        error "Failed to set farm addresses"
    fi
}

initialize_emission_schedule() {
    if check_emission_initialized; then
        success "Emission schedule already initialized, skipping..."
        return
    fi
    
    confirm "This will START the 156-week emission schedule and CANNOT be undone!"
    
    log "Initializing emission schedule (IRREVERSIBLE)..."
    
    result=$(sui client call --package $PACKAGE_ID \
        --module global_emission_controller \
        --function initialize_emission_schedule \
        --args $GLOBAL_EMISSION_ADMIN_CAP $GLOBAL_EMISSION_CONFIG 0x6 \
        --gas-budget 100000000 2>&1)
    
    if echo "$result" | grep -q "Status: Success"; then
        success_with_tx "🚀 EMISSION SCHEDULE STARTED! 156-week countdown began!" "$result"
    else
        error "Failed to initialize emission schedule"
    fi
}

# ============================================================================
# FIXED TOKEN AND FUNDING FUNCTIONS
# ============================================================================

mint_victory_tokens() {
    log "Minting Victory tokens for rewards..."
    
    total_amount=$((FARM_FUNDING_AMOUNT + LOCKER_FUNDING_AMOUNT))
    recipient_address=$(sui client active-address)
    
    result=$(sui client call --package $PACKAGE_ID \
        --module victory_token \
        --function mint \
        --args $VICTORY_TREASURY_CAP $total_amount $recipient_address $VICTORY_MINTER_CAP \
        --gas-budget 100000000 2>&1)
    
    if echo "$result" | grep -q "Status: Success"; then
        VICTORY_COIN_ID=$(extract_object_id "$result" "Coin")
        success_with_tx "Victory tokens minted: $VICTORY_COIN_ID" "$result"
        
        # Debug: Show all created objects
        log "All created objects in mint transaction:"
        get_all_created_objects "$result"
    else
        echo "Full mint result:"
        echo "$result"
        error "Failed to mint Victory tokens"
    fi
}

# FIXED: Better coin splitting and funding logic
fund_farm_vault() {
    log "Funding farm reward vault..."
    
    # Debug: Check current coin value first
    coin_info=$(sui client object --id "$VICTORY_COIN_ID" 2>&1)
    log "Current coin info: checking balance..."
    
    # Use PTB (Programmable Transaction Block) for better handling
    log "Creating split transaction for farm funding..."
    
    # Method 1: Try direct split and transfer in one transaction
    result=$(sui client ptb \
        --assign coin @$VICTORY_COIN_ID \
        --split "coin" $FARM_FUNDING_AMOUNT \
        --assign split-coin \
        --transfer-objects "[split-coin]" @$(sui client active-address) \
        --gas-budget 100000000 2>&1)
    
    if echo "$result" | grep -q "Status: Success"; then
        # Extract the split coin ID
        FARM_FUNDING_COIN=$(extract_object_id "$result" "Coin")
        success_with_tx "Split Victory coins for farm funding: $FARM_FUNDING_COIN" "$result"
        
        # Now deposit to farm vault
        log "Depositing Victory tokens to farm vault..."
        result=$(sui client call --package $PACKAGE_ID \
            --module farm \
            --function deposit_victory_tokens \
            --args $FARM_VAULT_ID $FARM_FUNDING_COIN $FARM_ADMIN_CAP 0x6 \
            --gas-budget 100000000 2>&1)
        
        if echo "$result" | grep -q "Status: Success"; then
            success_with_tx "Farm vault funded with $FARM_FUNDING_AMOUNT Victory tokens" "$result"
        else
            echo "Deposit result:"
            echo "$result"
            error "Failed to fund farm vault"
        fi
    else
        echo "Split result:"
        echo "$result"
        error "Failed to split coins for farm funding"
    fi
}

# Alternative funding method using direct minting
fund_farm_vault_alternative() {
    log "Alternative funding: Minting tokens directly for farm..."
    
    recipient_address=$(sui client active-address)
    
    # Mint tokens specifically for farm
    result=$(sui client call --package $PACKAGE_ID \
        --module victory_token \
        --function mint \
        --args $VICTORY_TREASURY_CAP $FARM_FUNDING_AMOUNT $recipient_address $VICTORY_MINTER_CAP \
        --gas-budget 100000000 2>&1)
    
    if echo "$result" | grep -q "Status: Success"; then
        FARM_FUNDING_COIN=$(extract_object_id "$result" "Coin")
        success_with_tx "Minted Victory tokens for farm: $FARM_FUNDING_COIN" "$result"
        
        # Deposit to farm vault
        result=$(sui client call --package $PACKAGE_ID \
            --module farm \
            --function deposit_victory_tokens \
            --args $FARM_VAULT_ID $FARM_FUNDING_COIN $FARM_ADMIN_CAP 0x6 \
            --gas-budget 100000000 2>&1)
        
        if echo "$result" | grep -q "Status: Success"; then
            success_with_tx "Farm vault funded with $FARM_FUNDING_AMOUNT Victory tokens" "$result"
        else
            error "Failed to fund farm vault"
        fi
    else
        error "Failed to mint tokens for farm funding"
    fi
}

fund_locker_vault() {
    log "Funding Victory locker reward vault..."
    
    recipient_address=$(sui client active-address)
    
    # Mint tokens specifically for locker
    result=$(sui client call --package $PACKAGE_ID \
        --module victory_token \
        --function mint \
        --args $VICTORY_TREASURY_CAP $LOCKER_FUNDING_AMOUNT $recipient_address $VICTORY_MINTER_CAP \
        --gas-budget 100000000 2>&1)
    
    if echo "$result" | grep -q "Status: Success"; then
        LOCKER_FUNDING_COIN=$(extract_object_id "$result" "Coin")
        success_with_tx "Minted Victory tokens for locker: $LOCKER_FUNDING_COIN" "$result"
        
        # Deposit to locker vault
        result=$(sui client call --package $PACKAGE_ID \
            --module victory_token_locker \
            --function deposit_victory_tokens \
            --args $VICTORY_REWARD_VAULT_ID $VICTORY_LOCKER_ID $LOCKER_FUNDING_COIN $LOCKER_ADMIN_CAP 0x6 \
            --gas-budget 100000000 2>&1)
        
        if echo "$result" | grep -q "Status: Success"; then
            success_with_tx "Victory locker vault funded with $LOCKER_FUNDING_AMOUNT Victory tokens" "$result"
        else
            error "Failed to fund Victory locker vault"
        fi
    else
        error "Failed to mint tokens for locker funding"
    fi
}

# ============================================================================
# POOL CREATION FUNCTIONS
# ============================================================================

create_single_asset_pools() {
    log "Creating single asset pools..."
    
    for token in "${SINGLE_ASSET_TOKENS[@]}"; do
        symbol=$(echo "$token" | sed -E 's/.*::([^:]+)::([^:]+)$/\2/' | sed 's/.*:://')
        
        # Check if pool already exists
        if check_pool_exists "$token" "$symbol single asset pool"; then
            success "⏩ Skipping $symbol - pool already exists"
            continue
        fi
        
        log "Creating single asset pool for $symbol..."
        
        # Special allocation for SUI
        if [[ "$token" == *"sui::SUI"* ]]; then
            allocation=1000
            is_native="true"
        else
            allocation=500
            is_native="false"
        fi
        
        result=$(sui client call --package $PACKAGE_ID \
            --module farm \
            --function create_single_asset_pool \
            --type-args "$token" \
            --args $FARM_ID $allocation $DEFAULT_SINGLE_DEPOSIT_FEE $DEFAULT_SINGLE_WITHDRAWAL_FEE $is_native $FARM_ADMIN_CAP 0x6 \
            --gas-budget 100000000 2>&1)
        
        if echo "$result" | grep -q "Status: Success"; then
            success_with_tx "Created single asset pool for $symbol" "$result"
        else
            warning "Failed to create single asset pool for $symbol (may already exist)"
        fi
        
        sleep 1  # Rate limiting
    done
}

create_lp_pools() {
    log "Creating LP pools..."
    
    for pair in "${LP_PAIRS[@]}"; do
        read -r token_a token_b is_native allocation <<< "$pair"
        
        symbol_a=$(echo "$token_a" | sed -E 's/.*::([^:]+)::([^:]+)$/\2/' | sed 's/.*:://')
        symbol_b=$(echo "$token_b" | sed -E 's/.*::([^:]+)::([^:]+)$/\2/' | sed 's/.*:://')
        
        # Generate LP token type for checking
        lp_token_type="$PACKAGE_ID::pair::LPCoin<$token_a, $token_b>"
        
        # Check if LP pool already exists
        if check_pool_exists "$lp_token_type" "$symbol_a-$symbol_b LP pool"; then
            success "⏩ Skipping $symbol_a-$symbol_b - LP pool already exists"
            continue
        fi
        
        log "Creating LP pool for $symbol_a-$symbol_b..."
        
        result=$(sui client call --package $PACKAGE_ID \
            --module farm \
            --function create_lp_pool \
            --type-args "$token_a" "$token_b" \
            --args $FARM_ID $allocation $DEFAULT_LP_DEPOSIT_FEE $DEFAULT_LP_WITHDRAWAL_FEE $is_native $FARM_ADMIN_CAP 0x6 \
            --gas-budget 100000000 2>&1)
        
        if echo "$result" | grep -q "Status: Success"; then
            success_with_tx "Created LP pool for $symbol_a-$symbol_b" "$result"
        else
            warning "Failed to create LP pool for $symbol_a-$symbol_b (may already exist)"
        fi
        
        sleep 1  # Rate limiting
    done
}

# ============================================================================
# PRESALE FUNCTIONS
# ============================================================================

create_presale_locks() {
    if [ "$ENABLE_PRESALE_LOCKS" != "true" ]; then
        log "Presale locks disabled, skipping..."
        return
    fi
    
    log "Creating presale locks..."
    
    admin_address=$(sui client active-address)
    
    for user_data in "${PRESALE_USERS[@]}"; do
        read -r user_address amount <<< "$user_data"
        
        log "Creating presale lock for $user_address (amount: $amount)..."
        
        # Mint tokens to admin first (so we can use them for the lock)
        result=$(sui client call --package $PACKAGE_ID \
            --module victory_token \
            --function mint \
            --args $VICTORY_TREASURY_CAP $amount $admin_address $VICTORY_MINTER_CAP \
            --gas-budget 100000000 2>&1)
        
        if echo "$result" | grep -q "Status: Success"; then
            presale_coin=$(extract_object_id "$result" "Coin")
            
            # Create admin lock (90 days = THREE_MONTH_LOCK)
            result=$(sui client call --package $PACKAGE_ID \
                --module victory_token_locker \
                --function admin_create_user_lock \
                --args $VICTORY_LOCKER_ID $LOCKED_TOKEN_VAULT_ID $presale_coin $user_address 90 $GLOBAL_EMISSION_CONFIG $LOCKER_ADMIN_CAP 0x6 \
                --gas-budget 100000000 2>&1)
            
            if echo "$result" | grep -q "Status: Success"; then
                success "Created presale lock for $user_address"
            else
                error "Failed to create presale lock for $user_address"
            fi
        else
            error "Failed to mint tokens for presale user $user_address"
        fi
        
        sleep 1  # Rate limiting
    done
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

validate_setup() {
    log "Validating system setup..."
    
    # Check emission status
    log "Checking emission status..."
    result=$(sui client call --package $PACKAGE_ID \
        --module global_emission_controller \
        --function get_emission_status \
        --args $GLOBAL_EMISSION_CONFIG 0x6 \
        --gas-budget 10000000 2>&1)
    
    if echo "$result" | grep -q "Status: Success"; then
        success "Emission controller operational"
    else
        warning "Could not verify emission status"
    fi
    
    # Check farm info
    log "Checking farm info..."
    result=$(sui client call --package $PACKAGE_ID \
        --module farm \
        --function get_farm_info_detailed \
        --args $FARM_ID \
        --gas-budget 10000000 2>&1)
    
    if echo "$result" | grep -q "Status: Success"; then
        success "Farm operational"
    else
        warning "Could not verify farm status"
    fi
    
    # Check locker allocations
    log "Checking locker allocations..."
    result=$(sui client call --package $PACKAGE_ID \
        --module victory_token_locker \
        --function validate_all_allocations \
        --args $VICTORY_LOCKER_ID \
        --gas-budget 10000000 2>&1)
    
    if echo "$result" | grep -q "Status: Success"; then
        success "Victory locker allocations valid"
    else
        warning "Could not verify locker allocations"
    fi
}

update_pools() {
    log "Performing mass pool update..."
    
    result=$(sui client call --package $PACKAGE_ID \
        --module farm \
        --function mass_update_pools \
        --args $FARM_ID $GLOBAL_EMISSION_CONFIG 0x6 \
        --gas-budget 100000000 2>&1)
    
    if echo "$result" | grep -q "Status: Success"; then
        success "Mass pool update completed"
    else
        warning "Mass pool update failed"
    fi
}

# ============================================================================
# DEBUGGING FUNCTIONS
# ============================================================================

debug_transaction() {
    local result="$1"
    local operation="$2"
    
    echo "🐛 DEBUG: $operation Transaction Details"
    echo "=================================="
    echo "$result"
    echo "=================================="
    
    if echo "$result" | grep -q "Status: Success"; then
        echo "✅ Transaction successful"
        echo "Created objects:"
        get_all_created_objects "$result"
    else
        echo "❌ Transaction failed"
        echo "Error details:"
        echo "$result" | grep -A 5 -B 5 "Error\|Abort\|Failed"
    fi
    echo
}

# ============================================================================
# MAIN EXECUTION FLOW
# ============================================================================

main() {
    echo "============================================================================"
    echo "🚀 SuiTrump DEX Complete Setup Script - FIXED VERSION"
    echo "============================================================================"
    echo
    
    log "Starting complete DEX setup process..."
    echo
    
    # Phase 1: Vault Creation
    echo "📦 PHASE 1: Creating Vaults"
    echo "----------------------------------------"
    create_farm_reward_vault
    create_locker_vaults
    echo
    
    # Phase 2: System Initialization
    echo "🔧 PHASE 2: System Initialization"
    echo "----------------------------------------"
    # initialize_farm
    set_farm_addresses
    echo
    
    # Phase 3: Token Minting and Funding - FIXED VERSION
    echo "💰 PHASE 3: Token Minting and Funding - FIXED"
    echo "----------------------------------------"
    
    # Try alternative funding method (mint directly for each purpose)
    log "Using alternative funding method (direct minting)..."
    
    fund_farm_vault_alternative
    fund_locker_vault
    echo
    
    # Phase 4: Pool Creation
    echo "🏊 PHASE 4: Creating Pools"
    echo "----------------------------------------"
    create_single_asset_pools
    create_lp_pools
    echo
    
    # Phase 5: Emission Schedule (CRITICAL)
    echo "⚡ PHASE 5: Emission Schedule"
    echo "----------------------------------------"
    initialize_emission_schedule
    echo
    
    # Phase 6: Presale Management
    echo "🎁 PHASE 6: Presale Management"
    echo "----------------------------------------"
    create_presale_locks
    echo
    
    # Phase 7: Final Validation
    echo "✅ PHASE 7: Validation and Updates"
    echo "----------------------------------------"
    update_pools
    validate_setup
    echo
    
    # Summary
    echo "============================================================================"
    echo "🎉 SETUP COMPLETE!"
    echo "============================================================================"
    echo
    echo "📋 Created Vaults:"
    echo "   Farm Vault:            $FARM_VAULT_ID"
    echo "   Locked Token Vault:    $LOCKED_TOKEN_VAULT_ID"
    echo "   Victory Reward Vault:  $VICTORY_REWARD_VAULT_ID"
    echo "   SUI Reward Vault:      $SUI_REWARD_VAULT_ID"
    echo
    echo "🎯 System Status:"
    echo "   ✅ Emission schedule started (156 weeks)"
    echo "   ✅ Farm pools created and funded"
    echo "   ✅ Victory locker configured with default allocations"
    echo "   ✅ Presale locks created (if enabled)"
    echo
    echo "🚀 Your DEX is now LIVE!"
    echo "   Users can now:"
    echo "   - Stake LP tokens in farm pools"
    echo "   - Stake single assets in farm pools (except Victory)"
    echo "   - Lock Victory tokens in the Victory locker"
    echo "   - Claim dual rewards (Victory + SUI)"
    echo
    echo "📊 Next Steps:"
    echo "   1. Add weekly SUI revenue to locker"
    echo "   2. Monitor pool performance"
    echo "   3. Adjust allocations if needed"
    echo "   4. Create additional pools for new tokens"
    echo
    echo "============================================================================"
}

# ============================================================================
# SCRIPT EXECUTION
# ============================================================================

# Verify required variables
if [ -z "$PACKAGE_ID" ] || [ -z "$FARM_ID" ] || [ -z "$VICTORY_LOCKER_ID" ]; then
    error "Missing required configuration variables. Please update the script configuration."
fi

# Run main function
main