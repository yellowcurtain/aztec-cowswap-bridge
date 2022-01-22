// SPDX-License-Identifier: GPL-2.0-only
// Copyright 2020 Spilsbury Holdings Ltd
pragma solidity >=0.6.10 <0.8.0;
pragma experimental ABIEncoderV2;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ICowswap } from "cowswap.sol";  //TODO
import { IDefiBridge } from "./interfaces/IDefiBridge.sol";
import { Types } from "./Types.sol";

// import 'hardhat/console.sol';

contract CowswapBridge is IDefiBridge {
  using SafeMath for uint256;
  address public immutable rollupProcessor;
  ICowswap cowswap;

  struct Interaction {
    string orderId;
  }
  mapping(uint256 => Interaction) pendingInteractions;

  constructor(address _rollupProcessor, address _cowswap) public {
    rollupProcessor = _rollupProcessor;
    cowswap = ICowswap(_cowswap);
  }

  receive() external payable {}

  function convert(
    Types.AztecAsset calldata inputAssetA,
    Types.AztecAsset calldata,
    Types.AztecAsset calldata outputAssetA,
    Types.AztecAsset calldata,
    uint256 inputValue,
    uint256 interactionNonce,
    uint64
  )
    external
    payable
    override
    returns (
      uint256,
      uint256,
      bool isAsync
    )
  {
    require(msg.sender == rollupProcessor, "CowswapBridge: INVALID_CALLER");
    isAsync = true;

    //GPv2VaultRelayer address on Mainnet
    address GPv2VaultRelayer = 0xc92e8bdf79f0507f65a392b0ab4667716bfe0110; 
    require(
      IERC20(inputAssetA.erc20Address).approve(address(GPv2VaultRelayer), inputValue),
      "CowswapBridge: APPROVE_FAILED"
    );

    //Cowswap only accept WETH
    require(
      inputAssetA.assetType != Types.AztecAssetType.ETH,
      "CowswapBridge: ONLY WETH"
    );
    
    //Future TODO: check is asset supported on cowswap

    uint256[] memory amounts;
    uint256 deadline = block.timestamp;

    // https://protocol-rinkeby.dev.gnosisdev.com/api/#/default/post_api_v1_orders
    //     {
    //   "sellToken": "0x6810e776880c02933d47db1b9fc05908e5386b96",
    //   "buyToken": "0x6810e776880c02933d47db1b9fc05908e5386b96",
    //   "receiver": "0x6810e776880c02933d47db1b9fc05908e5386b96",
    //   "sellAmount": "1234567890",
    //   "buyAmount": "1234567890",
    //   "validTo": 0,
    //   "appData": "0x0000000000000000000000000000000000000000000000000000000000000000",
    //   "feeAmount": "1234567890",
    //   "kind": "buy",
    //   "partiallyFillable": true,
    //   "sellTokenBalance": "erc20",
    //   "buyTokenBalance": "erc20",
    //   "signingScheme": "eip712",
    //   "signature": "0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
    //   "from": "0x6810e776880c02933d47db1b9fc05908e5386b96"
    // }

    //Future TODO: order params
    orderUid = cowswap.placeOrder();
    pendingInteractions[interactionNonce] = Interaction(orderUid);

    return (0,0,isAsync);
  }

  function canFinalise(
    uint256 interactionNonce
  ) external view override returns (bool) {
 
    orderUid = pendingInteractions[interactionNonce].orderUid;
    Types.OrderStatus orderstatus = cowswap.getOrderStatus(orderUid);

    bool executed;
    if (orderstatus == Types.OrderStatus.PRESIGNATUREPENDING || Types.OrderStatus.OPEN) {
      executed = false;
      require(executed == false, "Order Status: OPEN");
    } else {
      executed = true; 
    }

    return executed;
  }

  // call RollupContract.processAsyncDefiInteraction(uint256 interactionNonce), will get finalise called
  function finalise(
    Types.AztecAsset calldata,
    Types.AztecAsset calldata,
    Types.AztecAsset calldata,
    Types.AztecAsset calldata,
    uint256 interactionNonce,
    uint64
  ) external payable override returns (uint256, uint256) {

    require(msg.sender == rollupProcessor, "CowswapBridge: INVALID_CALLER");

    //Future TODO: notify swap process finished, and send output token back to aztec network. 
  }

}
