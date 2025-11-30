// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.10;

import "compound-protocol/contracts/Comptroller.sol";
import "compound-protocol/contracts/SimplePriceOracle.sol";
import "compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import "compound-protocol/contracts/CErc20.sol";
import "compound-protocol/contracts/CEther.sol";
import "compound-protocol/contracts/JumpRateModelV2.sol";

// compound use old solidity version
// compound on mainnet use master branch with compiler 0.8.10
// but revert to 0.5.16 on compilation.
//convert from file scripts-python\deployers\compound_deployer.py
// echidna and ganache can fork mainnet but much slower. rather just compile and deploy locally.
contract DeployerCompound {
    Comptroller public comptroller;
    SimplePriceOracle public oracle;

    address public mockETH;
    address public mockWBTC;
    address public mockDAI;
    address public mockUSDC;
    address public mockUSDT;
    address payable public admin;

    CTokenInterface public cEther;
    CTokenInterface public cWBTC;
    CTokenInterface public cDAI;
    CTokenInterface public cUSDC;
    CTokenInterface public cUSDT;

    constructor(
        address _mockETH,
        address _mockWBTC,
        address _mockDAI,
        address _mockUSDC,
        address _mockUSDT
    ) {
        admin = payable(msg.sender);
        mockETH = _mockETH;
        mockWBTC = _mockWBTC;
        mockDAI = _mockDAI;
        mockUSDC = _mockUSDC;
        mockUSDT = _mockUSDT;
    }

    function deployComptroller() public returns (address) {
        // from address 0x3d9819210a31b4961b30ef54be2aed79b9c9cd3b
        // no proxy
        //oracle is UniswapAnchoredView.sol . An admin confirmed TWAP price from validator.
        oracle = new SimplePriceOracle();
        comptroller = new Comptroller();
        // comptroller._setMaxAssets(20); //deprecated function
        comptroller._setPriceOracle(oracle);
        return address(comptroller);
    }

    // cETH uses whitepaper interest rate model
    uint cETH_baseRate = 20000000000000000; // 2% per year
    uint cETH_multiplier = 100000000000000000; // 0.1e18
    uint cETH_initialExchangeRate = 200000000000000000000000000;
    // cWBTC uses whitepaper interest rate model
    uint cWBTC_baseRate = 20000000000000000; // 2% per year
    uint cWBTC_multiplier = 300000000000000000; // 0.1e18
    uint cWBTC_initialExchangeRate = 20000000000000000;
    //cDai Jump model
    uint cDAI_baseRate = 0;
    uint cDAI_multiplier = 40000000000000000;
    uint cDAI_jumpMultiplierPerYear = 1090000000000000000;
    uint cDAI_kink = 800000000000000000;
    uint cDAI_initialExchangeRate = 200000000000000000000000000;
    //cUSDC Jump model
    uint cUSDC_baseRate = 0;
    uint cUSDC_multiplier = 40000000000000000;
    uint cUSDC_jumpMultiplierPerYear = 1090000000000000000;
    uint cUSDC_kink = 800000000000000000;
    uint cUSDC_initialExchangeRate = 200000000000000;
    //cUSDT Jump model
    uint cUSDT_baseRate = 0;
    uint cUSDT_multiplier = 40000000000000000;
    uint cUSDT_jumpMultiplierPerYear = 1090000000000000000;
    uint cUSDT_kink = 800000000000000000;
    uint cUSDT_initialExchangeRate = 200000000000000;

    function deployCTokens() public {
        WhitePaperInterestRateModel cETH_rateModel = new WhitePaperInterestRateModel(
                cETH_baseRate,
                cETH_multiplier
            );
        CEther _cEther = new CEther(
            ComptrollerInterface(comptroller),
            InterestRateModel(cETH_rateModel),
            cETH_initialExchangeRate,
            "Compound Ether",
            "cETH",
            8,
            admin
        );

        WhitePaperInterestRateModel cWBTC_rateModel = new WhitePaperInterestRateModel(
                cWBTC_baseRate,
                cWBTC_multiplier
            );
        CErc20 _cWBTC = new CErc20();
        _cWBTC.initialize(
            mockWBTC,
            ComptrollerInterface(comptroller),
            InterestRateModel(cWBTC_rateModel),
            cWBTC_initialExchangeRate,
            "Compound Wrapped BTC",
            "cWBTC",
            8
        );

        // deploy interest rate model
        JumpRateModelV2 cDAI_rateModel = new JumpRateModelV2(
            cDAI_baseRate,
            cDAI_multiplier,
            cDAI_jumpMultiplierPerYear,
            cDAI_kink,
            admin
        );
        CErc20 _cDAI = new CErc20();
        _cDAI.initialize(
            mockDAI,
            ComptrollerInterface(comptroller),
            InterestRateModel(cDAI_rateModel),
            cDAI_initialExchangeRate,
            "Compound Dai",
            "cDAI",
            8
        );

        // deploy interest rate model
        JumpRateModelV2 cUSDC_rateModel = new JumpRateModelV2(
            cUSDC_baseRate,
            cUSDC_multiplier,
            cUSDC_jumpMultiplierPerYear,
            cUSDC_kink,
            admin
        );
        CErc20 _cUSDC = new CErc20();
        _cUSDC.initialize(
            mockUSDC,
            ComptrollerInterface(comptroller),
            InterestRateModel(cUSDC_rateModel),
            cUSDC_initialExchangeRate,
            "Compound USDC",
            "cUSDC",
            8
        );

        // deploy interest rate model
        JumpRateModelV2 cUSDT_rateModel = new JumpRateModelV2(
            cUSDT_baseRate,
            cUSDT_multiplier,
            cUSDT_jumpMultiplierPerYear,
            cUSDT_kink,
            admin
        );
        CErc20 _cUSDT = new CErc20();
        _cUSDT.initialize(
            mockUSDT,
            ComptrollerInterface(comptroller),
            InterestRateModel(cUSDT_rateModel),
            cUSDT_initialExchangeRate,
            "Compound USDT",
            "cUSDT",
            8
        );

        cEther = CTokenInterface(_cEther);
        cWBTC = CTokenInterface(_cWBTC);
        cDAI = CTokenInterface(_cDAI);
        cUSDC = CTokenInterface(_cUSDC);
        cUSDT = CTokenInterface(_cUSDT);
    }
}
