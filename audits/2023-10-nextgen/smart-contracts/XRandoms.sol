// SPDX-License-Identifier: MIT

/**
 *
 *  @title: NextGen Word Pool
 *  @date: 09-October-2023 
 *  @version: 1.1
 *  @author: 6529 team
 */

pragma solidity ^0.8.19;
//The randomPool smart contract is used by the RandomizerNXT contract, once it's called from the RandomizerNXT smart contract it returns a random word from the current word pool as well as a random number back to the RandomizerNXT smart contract which uses those values to generate a random hash.
contract randomPool {

    function getWord(uint256 id) private pure returns (string memory) {
        
        // array storing the words list
        string[100] memory wordsList = ["Acai", "Ackee", "Apple", "Apricot", "Avocado", "Babaco", "Banana", "Bilberry", "Blackberry", "Blackcurrant", "Blood Orange", 
        "Blueberry", "Boysenberry", "Breadfruit", "Brush Cherry", "Canary Melon", "Cantaloupe", "Carambola", "Casaba Melon", "Cherimoya", "Cherry", "Clementine", 
        "Cloudberry", "Coconut", "Cranberry", "Crenshaw Melon", "Cucumber", "Currant", "Curry Berry", "Custard Apple", "Damson Plum", "Date", "Dragonfruit", "Durian", 
        "Eggplant", "Elderberry", "Feijoa", "Finger Lime", "Fig", "Gooseberry", "Grapes", "Grapefruit", "Guava", "Honeydew Melon", "Huckleberry", "Italian Prune Plum", 
        "Jackfruit", "Java Plum", "Jujube", "Kaffir Lime", "Kiwi", "Kumquat", "Lemon", "Lime", "Loganberry", "Longan", "Loquat", "Lychee", "Mammee", "Mandarin", "Mango", 
        "Mangosteen", "Mulberry", "Nance", "Nectarine", "Noni", "Olive", "Orange", "Papaya", "Passion fruit", "Pawpaw", "Peach", "Pear", "Persimmon", "Pineapple", 
        "Plantain", "Plum", "Pomegranate", "Pomelo", "Prickly Pear", "Pulasan", "Quine", "Rambutan", "Raspberries", "Rhubarb", "Rose Apple", "Sapodilla", "Satsuma", 
        "Soursop", "Star Apple", "Star Fruit", "Strawberry", "Sugar Apple", "Tamarillo", "Tamarind", "Tangelo", "Tangerine", "Ugli", "Velvet Apple", "Watermelon"];
        //@gas memory wordslist instead of loading from storage will cause significant gas overhead
        // returns a word based on index
        if (id==0) {
            return wordsList[id];
        } else {
            return wordsList[id - 1];//@gas 8797 gas. convert list to bytes32 array immutable. which support init directly
        }
        }

    function randomNumber() public view returns (uint256){
        uint256 randomNum = uint(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), block.timestamp))) % 1000;
        return randomNum;
    }

    function randomWord() public view returns (string memory) {
        uint256 randomNum = uint(keccak256(abi.encodePacked(block.prevrandao, blockhash(block.number - 1), block.timestamp))) % 100;//@audit-ok M random word return 99 words not 100th word in list
        return getWord(randomNum);
    }

    function returnIndex(uint256 id) public view returns (string memory) {
        return getWord(id);
    }

}

    // function randomWord(uint256 _num) public pure returns (string memory) {
    //     uint256 randomNum = _num % 100;
    //     return getWord(randomNum);
    // }

    // function getWord(uint256 id) private pure returns (string memory) {
    //     // array storing the words list
    //     string[100] memory wordsList = [
    //         "Acai",
    //         "Ackee",
    //         "Apple",
    //         "Apricot",
    //         "Avocado",
    //         "Babaco",
    //         "Banana",
    //         "Bilberry",
    //         "Blackberry",
    //         "Blackcurrant",
    //         "Blood Orange",
    //         "Blueberry",
    //         "Boysenberry",
    //         "Breadfruit",
    //         "Brush Cherry",
    //         "Canary Melon",
    //         "Cantaloupe",
    //         "Carambola",
    //         "Casaba Melon",
    //         "Cherimoya",
    //         "Cherry",
    //         "Clementine",
    //         "Cloudberry",
    //         "Coconut",
    //         "Cranberry",
    //         "Crenshaw Melon",
    //         "Cucumber",
    //         "Currant",
    //         "Curry Berry",
    //         "Custard Apple",
    //         "Damson Plum",
    //         "Date",
    //         "Dragonfruit",
    //         "Durian",
    //         "Eggplant",
    //         "Elderberry",
    //         "Feijoa",
    //         "Finger Lime",
    //         "Fig",
    //         "Gooseberry",
    //         "Grapes",
    //         "Grapefruit",
    //         "Guava",
    //         "Honeydew Melon",
    //         "Huckleberry",
    //         "Italian Prune Plum",
    //         "Jackfruit",
    //         "Java Plum",
    //         "Jujube",
    //         "Kaffir Lime",
    //         "Kiwi",
    //         "Kumquat",
    //         "Lemon",
    //         "Lime",
    //         "Loganberry",
    //         "Longan",
    //         "Loquat",
    //         "Lychee",
    //         "Mammee",
    //         "Mandarin",
    //         "Mango",
    //         "Mangosteen",
    //         "Mulberry",
    //         "Nance",
    //         "Nectarine",
    //         "Noni",
    //         "Olive",
    //         "Orange",
    //         "Papaya",
    //         "Passion fruit",
    //         "Pawpaw",
    //         "Peach",
    //         "Pear",
    //         "Persimmon",
    //         "Pineapple",
    //         "Plantain",
    //         "Plum",
    //         "Pomegranate",
    //         "Pomelo",
    //         "Prickly Pear",
    //         "Pulasan",
    //         "Quine",
    //         "Rambutan",
    //         "Raspberries",
    //         "Rhubarb",
    //         "Rose Apple",
    //         "Sapodilla",
    //         "Satsuma",
    //         "Soursop",
    //         "Star Apple",
    //         "Star Fruit",
    //         "Strawberry",
    //         "Sugar Apple",
    //         "Tamarillo",
    //         "Tamarind",
    //         "Tangelo",
    //         "Tangerine",
    //         "Ugli",
    //         "Velvet Apple",
    //         "Watermelon"
    //     ];

    //     // returns a word based on index
    //     if (id == 0) {
    //         return wordsList[id];
    //     } else {
    //         return wordsList[id - 1];
    //     }
    // }