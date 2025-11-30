// SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;
pragma solidity >=0.8.0 <0.9.0;

import { FighterOps } from "./FighterOps.sol";

/// @title AI Arena Helper
/// @author ArenaX Labs Inc.
/// @notice This contract generates and manages an AI Arena fighters physical attributes.
contract AiArenaHelper {

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice List of attributes
    string[] public attributes = ["head", "eyes", "mouth", "body", "hands", "feet"];

    /// @notice Default DNA divisors for attributes
    uint8[] public defaultAttributeDivisor = [2, 3, 5, 7, 11, 13];

    /// The address that has owner privileges (initially the contract deployer).
    address _ownerAddress;

    /*//////////////////////////////////////////////////////////////
                                MAPPINGS
    //////////////////////////////////////////////////////////////*/    
    
    /// @notice Mapping tracking fighter generation to attribute probabilities
    mapping(uint256 => mapping(string => uint8[])) public attributeProbabilities;//@audit-ok L probalities array is fixed to array of 6. while mappinng support infinite array length
    //@ attributeProbabilities length can be bigger than 6. 
    /// @notice Mapping of attribute to DNA divisors
    mapping(string => uint8) public attributeToDnaDivisor;//@note all attributes and probabilities fixed to array of 6

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @dev Constructor to initialize the contract with the attribute probabilities for gen 0.
    /// @param probabilities An array of attribute probabilities for the generation.
    constructor(uint8[][] memory probabilities) {//@note probability is 6x6 array
        _ownerAddress = msg.sender;

        // Initialize the probabilities for each attribute
        addAttributeProbabilities(0, probabilities);//@note probabilities total is not 100 but a ratio

        uint256 attributesLength = attributes.length;
        for (uint8 i = 0; i < attributesLength; i++) {
            attributeProbabilities[0][attributes[i]] = probabilities[i];//@audit-ok L this rewrite the previous line of manual function
            attributeToDnaDivisor[attributes[i]] = defaultAttributeDivisor[i];
        }
    } 

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfers ownership from one address to another.
    /// @dev Only the owner address is authorized to call this function.
    /// @param newOwnerAddress The address of the new owner
    function transferOwnership(address newOwnerAddress) external {
        require(msg.sender == _ownerAddress);
        _ownerAddress = newOwnerAddress;
    }

    /// @notice Add attribute divisors for attributes.
    /// @param attributeDivisors An array of attribute divisors.
    function addAttributeDivisor(uint8[] memory attributeDivisors) external {
        require(msg.sender == _ownerAddress);
        require(attributeDivisors.length == attributes.length);

        uint256 attributesLength = attributes.length;
        for (uint8 i = 0; i < attributesLength; i++) {
            attributeToDnaDivisor[attributes[i]] = attributeDivisors[i];
        }
    }    

    /// @notice Create physical attributes for a fighter based on DNA.
    /// @param dna The DNA of the fighter.
    /// @param iconsType Type of icons fighter (0 means it's not an icon).
    /// @param dendroidBool Whether the fighter is a dendroid or not
    /// @return Fighter physical attributes.
    function createPhysicalAttributes(
        uint256 dna, 
        uint8 generation, 
        uint8 iconsType, 
        bool dendroidBool
    ) 
        external 
        view 
        returns (FighterOps.FighterPhysicalAttributes memory) 
    {
        if (dendroidBool) {
            return FighterOps.FighterPhysicalAttributes(99, 99, 99, 99, 99, 99);
        } else {
            uint256[] memory finalAttributeProbabilityIndexes = new uint[](attributes.length);

            uint256 attributesLength = attributes.length;//0: head, 1: eyes, 2: mouth, 3: body, 4: hands, 5: feet
            for (uint8 i = 0; i < attributesLength; i++) {
                if (
                  i == 0 && iconsType == 2 || // Custom icons head (beta helmet)
                  i == 1 && iconsType > 0 || // Custom icons eyes (red diamond)//@audit-ok M how you suppose to change NFT eye later? If project include more cosmetic change?
                  i == 4 && iconsType == 3 // Custom icons hands (bowling ball)
                ) {
                    finalAttributeProbabilityIndexes[i] = 50;
                } else {//@ dnaDivisor [2, 3, 5, 7, 11, 13] or head: 2, eyes: 3, mouth: 5, body: 7, hands: 11, feet: 13
                    uint256 rarityRank = (dna / attributeToDnaDivisor[attributes[i]]) % 100;//@rarityRank range from 0 to 99
                    uint256 attributeIndex = dnaToIndex(generation, rarityRank, attributes[i]);
                    finalAttributeProbabilityIndexes[i] = attributeIndex;
                }
            }
            return FighterOps.FighterPhysicalAttributes(
                finalAttributeProbabilityIndexes[0],//@note final attribute index always smaller than 6. range 1-6. suppose not 0
                finalAttributeProbabilityIndexes[1],
                finalAttributeProbabilityIndexes[2],
                finalAttributeProbabilityIndexes[3],
                finalAttributeProbabilityIndexes[4],
                finalAttributeProbabilityIndexes[5]
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

     /// @notice Add attribute probabilities for a given generation.
     /// @dev Only the owner can call this function.
     /// @param generation The generation number.
     /// @param probabilities An array of attribute probabilities for the generation.
    function addAttributeProbabilities(uint256 generation, uint8[][] memory probabilities) public {
        require(msg.sender == _ownerAddress);
        require(probabilities.length == 6, "Invalid number of attribute arrays");
        //@audit-ok L first validation check if probabilities is updated with length longer than 50. dnaToIndex will hit premium DNA
        uint256 attributesLength = attributes.length;
        for (uint8 i = 0; i < attributesLength; i++) {
            attributeProbabilities[generation][attributes[i]] = probabilities[i];//@ this i length must be check for length less than 50
        }//@audit-ok M second validation check. probabilities total must less than 100 or <=99
    }

     /// @notice Delete attribute probabilities for a given generation. 
     /// @dev Only the owner can call this function.
     /// @param generation The generation number.
    function deleteAttributeProbabilities(uint8 generation) public {
        require(msg.sender == _ownerAddress);

        uint256 attributesLength = attributes.length;
        for (uint8 i = 0; i < attributesLength; i++) {
            attributeProbabilities[generation][attributes[i]] = new uint8[](0);
        }
    }

     /// @dev Get the attribute probabilities for a given generation and attribute.
     /// @param generation The generation number.
     /// @param attribute The attribute name.
     /// @return Attribute probabilities.
    function getAttributeProbabilities(uint256 generation, string memory attribute) 
        public 
        view 
        returns (uint8[] memory) 
    {
        return attributeProbabilities[generation][attribute];
    }    

     /// @dev Convert DNA and rarity rank into an attribute probability index.
     /// @param attribute The attribute name.
     /// @param rarityRank The rarity rank.
     /// @return attributeProbabilityIndex attribute probability index.
    function dnaToIndex(uint256 generation, uint256 rarityRank, string memory attribute) //@note most of dendroid attributeProbabilityIndex is 1. if rarity overshoot 95%. it return 0
        public 
        view 
        returns (uint256 attributeProbabilityIndex) //@audit-ok M dnaToIndex do have NULL value 0. No clue what this index stand for
    {
        uint8[] memory attrProbabilities = getAttributeProbabilities(generation, attribute);//@head: [25, 25, 13, 13, 9, 9] +=94
        //@body : [25, 25, 13, 13, 9, 23] +=108
        uint256 cumProb = 0;//@hands : [25, 25, 13, 13, 9, 1] +=86
        uint256 attrProbabilitiesLength = attrProbabilities.length;
        for (uint8 i = 0; i < attrProbabilitiesLength; i++) {//@this array default 6 or possible more
            cumProb += attrProbabilities[i];
            if (cumProb >= rarityRank) {//@rarityRank 0-99
                attributeProbabilityIndex = i + 1;
                break;
            }
        }
        return attributeProbabilityIndex;//@cum prob total less than 95. and rarity roll is 99. it return 0 
    }
}


