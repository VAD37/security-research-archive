package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strconv"

	"golang.org/x/crypto/sha3"
)

func main() {
	matchHex := 0x1626ba7e
	fmt.Println("Match Hex:", strconv.FormatInt(int64(matchHex), 16))
	// The string to be hashed
	baseString := "CHALLENGE_MAGIC" //0x19bb34e293bba96bf0caeea54cdd3d2dad7fdf44cbea855173fa84534fcfb528
	keccak_hasher := sha3.NewLegacyKeccak256()
	keccak_hasher.Write([]byte(baseString))
	keccakhashed := keccak_hasher.Sum(nil)
	magixHex := hex.EncodeToString(keccakhashed)
	fmt.Println("CHALLENGE_MAGIC Hashed Hex:", magixHex)

	//valid signature call take in SHA256 bytes32 hash and bytes memory signature. which are abi.encodePacked. we just need to find correct signatyre togenerate coorect bytes matching result
	//extra uint256 3341776893
	//convert matchHex into selector bytes4
	selector, err := hex.DecodeString("1626ba7e")
	if err != nil {
		panic(err)
	}
	magicHash := keccakhashed
	concate := append(selector, magicHash...)
	concate = append(concate, HexPaddingUint256(64)...)
	concate = append(concate, HexPaddingUint256(32)...)
	// concate = append(concate, HexPaddingUint256(3341776893)...)

	fmt.Println("Concate:", hex.EncodeToString(concate))

	hashedSha256 := sha256.Sum256(concate)

	hashedSha256Hex := hex.EncodeToString([]byte(hashedSha256[:]))
	//convert selector byte[] into [32]byte

	// this result in the same as solidity  sha256 abi.encodePacked
	// loop for while use counter until we find hash
	// Counter for modifying the baseString
	// slice selector into [4]byte
	selectorBytes := selector[:]

	var counter uint64 = 0
	for {

		hash := sha256.Sum256(append(concate, HexPaddingUint256(counter)...))

		// Check if the hash first 4 bytes matches selector 4 bytes
		if hash[0] == selectorBytes[0] && hash[1] == selectorBytes[1] && hash[2] == selectorBytes[2] && hash[3] == selectorBytes[3] {
			fmt.Println("Match found!")
			fmt.Println(counter)
			fmt.Printf("Hash: %s\n", hex.EncodeToString([]byte(hash[:])))
			break
		}

		// Increment the counter for the next iteration
		counter++
		if counter%10000000 == 0 {
			fmt.Printf("Counter: %d\n", counter)
		}
	}

	fmt.Println("Hashed SHA256 Hex:", hashedSha256Hex)
	//final result 0x1626ba7e

}

// super fast and efficient hex padding uint into bytes32 []byte
func HexPaddingUint256(i uint64) []byte {
	b := make([]byte, 32)
	b[31] = byte(i)
	b[30] = byte(i >> 8)
	b[29] = byte(i >> 16)
	b[28] = byte(i >> 24)
	b[27] = byte(i >> 32)
	b[26] = byte(i >> 40)
	b[25] = byte(i >> 48)
	b[24] = byte(i >> 56)
	return b
}
