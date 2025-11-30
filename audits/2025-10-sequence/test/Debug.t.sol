// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import { Factory } from "../src/Factory.sol";
import "forge-std/console.sol";

import { Stage1Module } from "../src/Stage1Module.sol";
import { Stage2Module } from "../src/Stage2Module.sol";
import { AdvTest } from "./utils/TestUtils.sol";

import { Payload } from "../src/modules/Payload.sol";

import { BaseAuth } from "../src/modules/auth/BaseAuth.sol";

import { SelfAuth } from "../src/modules/auth/SelfAuth.sol";

import { Calls } from "../src/modules/Calls.sol";
import { Stage1Auth } from "../src/modules/auth/Stage1Auth.sol";
import { IPartialAuth } from "../src/modules/interfaces/IPartialAuth.sol";

import { ISapient } from "../src/modules/interfaces/ISapient.sol";
import { PrimitivesRPC } from "./utils/PrimitivesRPC.sol";
import { AdvTest } from "./utils/TestUtils.sol";

contract DebugTest is AdvTest {

  //https://github.com/0xsequence/live-contracts
  // │ sequence_v3/rc_3     │ GuestV3                           │ 0x0000000000601fcA38f0cCA649453F6739436d6C │
  // │ sequence_v3/rc_3     │ PasskeysV3                        │ 0x0000000000dc2d96870dc108c5E15570B715DFD2 │
  // │ sequence_v3/rc_3     │ RecoveryV3                        │ 0x0000000000213697bCA95E7373787a40858a51C7 │
  // │ sequence_v3/rc_3     │ SequenceV3/rc3FactoryV3           │ 0x00000000000018A77519fcCCa060c2537c9D6d3F │
  // │ sequence_v3/rc_3     │ SessionsV3                        │ 0x0000000000CC58810c33F3a0D78aA1Ed80FaDcD8 │
  // │ sequence_v3/rc_3     │ Stage1Module433707V3              │ 0x0000000000005A02E3218e820EA45102F84A35C7 │
  // │ sequence_v3/rc_3     │ Stage1ModuleV3                    │ 0x00000000000084fA81809Dd337311297C5594d62 │ //@this one does not have entry point
  // │ sequence_v3/rc_3     │ Stage2Module.valueV3              │ 0x7438718F9E4b9B834e305A620EEeCf2B9E6eBE79 │
  // │ sequence_v3/rc_3     │ Stage2Module433707.valueV3        │ 0x7706aaC0cc2C42C01CE17136F7475b0E46F2ABA1 │
  Factory public factory = Factory(0x00000000000018A77519fcCCa060c2537c9D6d3F);
  Stage1Module public module = Stage1Module(payable(0x00000000000084fA81809Dd337311297C5594d62));

  function setUp() public {
    //local setup
    vm.etch(address(factory), type(Factory).runtimeCode);
    vm.etch(address(module), address(new Stage1Module(address(factory), address(0))).code);

    vm.label(address(factory), "Factory");
    vm.label(address(module), "Stage1Module");
    vm.label(address(module.STAGE_2_IMPLEMENTATION()), "Stage2Module");

    // _fork();
  }

  function _fork() internal {
    // fork mainnet at block 23381712. Before the wallet is created
    vm.createSelectFork("https://eth-mainnet.alchemyapi.io/v2/kIP2_euA9T6Z-e5MjHzTzRUmgqCLsHUA", 23381712);
    vm.label(address(factory), "Factory");
    vm.label(address(module), "Stage1Module");
    vm.label(address(module.STAGE_2_IMPLEMENTATION()), "Stage2Module");
    vm.label(address(module.FACTORY()), "Factory");
    vm.label(0xFF8f46538c39dCA637fCE9a804b2B59B517A9698, "TrailsMulticall3Router");
    vm.label(0xcA11bde05977b3631167028862bE2a173976CA11, "Multicall3");
    vm.label(0xa5F565650890fBA1824Ee0F21EbBbF660a179934, "RelayReceiver");
    vm.label(0x5CdC654bc149F72509442fa9c12762b269f34c23, "TrailsTokenSweeper");
  }

  // function test_debugWallet() public {
  //   //mimic this transaction 0x3284207b969b63abf988134db60324e5fbd896d7bfd21d015d55a79192f55891 on Mainnet
  //   //1. call factory to deploy wallet with salt
  //   //2. execute call to wallet. wallet proxy to Stage1Module.execute()
  //   //3. wallet execute call to TrailsMulticall3Router. this transaction just pay relay
  //   // Skip onlyFallback calls if no error occurred //4. wallet execute Sweep token through delegate

  //   console.logBytes32(module.INIT_CODE_HASH());
  //   console.log(module.FACTORY());
  //   console.log(module.STAGE_2_IMPLEMENTATION());
  //   console.log(module.entrypoint());

  //   //GuestV3 make a multicall
  //   // [{"to":"0x00000000000018a77519fccca060c2537c9d6d3f","value":"0","data":"0x32c02a1400000000000000000000000000000000000084fa81809dd337311297c5594d629e605e57b90f14aa986a54ec32e1b58d87d06dc90c8018a281752166916d4e21","gasLimit":"0","delegateCall":false,"onlyFallback":false,"behaviorOnError":"0"},
  //   //{"to":"0xbee4642c3b315bbfd3a93fd56fb2b15dd5de391f","value":"0","data":"0x1f6a1eb90000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000034000000000000000000000000000000000000000000000000000000000000002d6010306ff8f46538c39dca637fce9a804b2b59b517a96980000000000000000000000000000000000000000000000000003f8ec787e636b00018409c5eabe00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000124174dea71000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000a5f565650890fba1824ee0f21ebbbf660a17993400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003f8ec787e636b0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000002097b4ef8092ec3101b13584912deb3f0f5a34582edc95b7be25128b8b2119485500000000000000000000000000000000000000000000000000000000145cdc654bc149f72509442fa9c12762b269f34c230000649f795aac00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003f8ec787e636b00000000000000000000000076008498f26789dd8b691bebe24c889a3dd1a2fc345cdc654bc149f72509442fa9c12762b269f34c230000844784226e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000097c4a952b46becad0663f76357d3776ba11566e10000000000000000000000000000000000000000000000000003f8ec787e636b00000000000000000000000076008498f26789dd8b691bebe24c889a3dd1a2fc0000000000000000000000000000000000000000000000000000000000000000000000000000000000390400011197c4a952b46becad0663f76357d3776ba11566e1801c5b52498d74901f2ab5af572eaaef36dc1a508cbb43cf86f55bc0686ec24de100000000000000","gasLimit":"0","delegateCall":false,"onlyFallback":false,"behaviorOnError":"0"}]
  //   //1. call factory to deploy wallet with salt
  //   // factory.deploy(module, _salt);
  //   bytes32 salt = 0x9e605e57b90f14aa986a54ec32e1b58d87d06dc90c8018a281752166916d4e21;
  //   address payable wallet = payable(factory.deploy(address(module), salt));
  //   vm.label(wallet, "Wallet");
  //   // vm.assertEq(wallet, 0xbEE4642C3B315bbFd3a93Fd56fB2B15DD5DE391F);
  //   vm.deal(wallet, 0.001202872639255457 ether);
  //   //2. Guest execute call on Wallet proxy.
  //   bytes memory data =
  //     hex"010306ff8f46538c39dca637fce9a804b2b59b517a96980000000000000000000000000000000000000000000000000003f8ec787e636b00018409c5eabe00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000124174dea71000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000a5f565650890fba1824ee0f21ebbbf660a17993400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003f8ec787e636b0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000002097b4ef8092ec3101b13584912deb3f0f5a34582edc95b7be25128b8b2119485500000000000000000000000000000000000000000000000000000000145cdc654bc149f72509442fa9c12762b269f34c230000649f795aac00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003f8ec787e636b00000000000000000000000076008498f26789dd8b691bebe24c889a3dd1a2fc345cdc654bc149f72509442fa9c12762b269f34c230000844784226e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000097c4a952b46becad0663f76357d3776ba11566e10000000000000000000000000000000000000000000000000003f8ec787e636b00000000000000000000000076008498f26789dd8b691bebe24c889a3dd1a2fc";
  //   bytes memory signature =
  //     hex"0400011197c4a952b46becad0663f76357d3776ba11566e1801c5b52498d74901f2ab5af572eaaef36dc1a508cbb43cf86f55bc0686ec24de1";
  //   Stage1Module(wallet).execute(data, signature);
  //   console.log("done");
  // }

  struct test_receiveETH_stage2_params {
    uint256 pk;
    uint256 nextPk;
    uint16 threshold;
    uint16 nextThreshold;
    uint56 checkpoint;
  }

  struct test_receiveETH_stage2_vars {
    address signer;
    address payable wallet;
    bytes updateConfigSignature;
    bytes updateConfigPackedPayload;
    string ogCe;
    string ogConfig;
    string nextCe;
    string nextConfig;
    bytes32 ogConfigHash;
    bytes32 nextConfigHash;
  }

  function _debugSetImageHashConfig() public {
    Stage1Module stage1Module = module;
    test_receiveETH_stage2_params memory params;
    params.pk = uint(0xb59b4e3239335f86cad17ce024c1acef18085fd39d32f5b9ee482fd49566b4f8);//addr:0x6c487C5C1Aa85F7C4CDf5ed89f6D2343Ed66CC2a

    test_receiveETH_stage2_vars memory vars;
    vars.signer = vm.addr(params.pk);

    // Original config (stage1)
    vars.ogCe = string(abi.encodePacked("signer:", vm.toString(vars.signer), ":1"));
    vars.ogConfig = PrimitivesRPC.newConfig(vm, 1, 0, vars.ogCe);
    vars.ogConfigHash = PrimitivesRPC.getImageHash(vm, vars.ogConfig);

    // Deploy wallet in stage1
    console.log("- Deploying wallet in stage1...");
    
    emit log_named_bytes32("salt stage1", vars.ogConfigHash);
    vars.wallet = payable(factory.deploy(address(stage1Module), vars.ogConfigHash));

    // Next config (what we'll update to)
    vars.nextCe = string(abi.encodePacked("signer:", vm.toString(vars.signer), ":1"));
    vars.nextConfig = PrimitivesRPC.newConfig(vm, 1, 1, vars.nextCe);
    vars.nextConfigHash = PrimitivesRPC.getImageHash(vm, vars.nextConfig);

    // Construct the payload to update the imageHash (which transitions us to stage2)
    Payload.Decoded memory updateConfigPayload;
    updateConfigPayload.kind = Payload.KIND_TRANSACTIONS;
    updateConfigPayload.calls = new Payload.Call[](1);
    updateConfigPayload.calls[0] = Payload.Call({
      to: address(vars.wallet),
      value: 0,
      data: abi.encodeWithSelector(BaseAuth.updateImageHash.selector, vars.nextConfigHash),
      gasLimit: 100000,
      delegateCall: false,
      onlyFallback: false,
      behaviorOnError: Payload.BEHAVIOR_REVERT_ON_ERROR
    });

    // Sign the payload using the original config
    (uint256 v, bytes32 r, bytes32 s) = vm.sign(params.pk, Payload.hashFor(updateConfigPayload, vars.wallet));
    vars.updateConfigSignature = PrimitivesRPC.toEncodedSignature(
      vm,
      vars.ogConfig,
      string(
        abi.encodePacked(vm.toString(vars.signer), ":hash:", vm.toString(r), ":", vm.toString(s), ":", vm.toString(v))
      ),
      true
    );

    // Pack the payload and execute
    vars.updateConfigPackedPayload = PrimitivesRPC.toPackedPayload(vm, updateConfigPayload);
    // vm.expectEmit(true, true, false, true, vars.wallet);
    // emit ImageHashUpdated(vars.nextConfigHash);
    console.log("- Executing updateConfig to move to stage2...");
    emit log_named_bytes32("next imageHash", vars.nextConfigHash);
    Stage1Module(vars.wallet).execute(vars.updateConfigPackedPayload, vars.updateConfigSignature);

    // Confirm that the wallet is now running stage2
    assertEq(Stage1Module(vars.wallet).getImplementation(), stage1Module.STAGE_2_IMPLEMENTATION());

    // Send 1 ether to the newly upgraded wallet
    vm.deal(address(this), 1 ether);
    vars.wallet.transfer(1 ether);

    // Check that the wallet received the ether
    assertEq(address(vars.wallet).balance, 1 ether);
  }

}
