// SPDX-License-Identifier: GPL-2.0-only

pragma solidity >=0.6.10 <0.8.10;
pragma experimental ABIEncoderV2;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { IGPv2Settlement } from './interfaces/IGPv2Settlement.sol'; 
import { IERC20 } from "./interfaces/IERC20.sol";
import { IRollupProcessor } from "./interfaces/IRollupProcessor.sol";
import { IDefiBridge } from "./interfaces/IDefiBridge.sol";
import { Types } from "./Types.sol";

/// @title Bridge Contract between Aztec and Cowswap
/// @author yellowcurtain
contract CowswapBridge is IDefiBridge {

  using SafeMath for uint256;
  using SafeMath for uint32;

  /// @dev The settlement contract of cowswap order
  /// call setPreSignature function of GPv2Settlement to activate order
  IGPv2Settlement public immutable cowswapSettlement;
  
  /// @dev The Vault relayer which can interact on behalf of users
  /// used by cowswap to transfer funds from bridge
  address public immutable vaultRelayer;

  /// @dev Smart contract responsible for processing Aztec zkRollups
  /// https://github.com/AztecProtocol/aztec-2-bug-bounty/blob/master/contracts/RollupProcessor.sol
  address public immutable rollupProcessor;
  
  /// @dev Unsigned orders in cowswap
  /// Prepare unsigned orders in order to call setPreSignature to sign and activate order
  Types.CowswapOrder[] public presignedOrders;

  /// @dev Interaction nonce array
  /// Interaction nonce is a globally unique identifier for DeFi interaction
  uint256[] public interactionNonces;

  /// @dev Interactions
  mapping(uint256 => Types.Interaction) interactions;

  /// @dev A offchain notifier monitors Trade event and find matching orderUid
  ///        event Trade(address indexed owner,
  ///          IERC20 sellToken,IERC20 buyToken,uint256 sellAmount,
  ///          uint256 buyAmount,uint256 feeAmount,bytes orderUid);
  /// Get executed trade result and set sellAmount for each orderUid
  mapping(bytes => uint256) public outputAmounts;

  /// @dev Empty receive function
  /// Allow bridge contract to receive Ether
  receive() external payable {}

  constructor(address _cowswapSettlement, address _rollupProcessor, address _vaultRelayer) public 
  {
    cowswapSettlement = IGPv2Settlement(_cowswapSettlement);
    rollupProcessor = _rollupProcessor;
    vaultRelayer = _vaultRelayer;
  }

  // @dev This function is called from the RollupProcessor.sol contract via the DefiBridgeProxy. It receives the aggreagte sum of all users funds for the input assets.
  // @param AztecAsset inputAssetA a struct detailing the first input asset, this will always be set
  // @param AztecAsset inputAssetB an optional struct detailing the second input asset, this is used for repaying borrows and should be virtual
  // @param AztecAsset outputAssetA a struct detailing the first output asset, this will always be set
  // @param AztecAsset outputAssetB a struct detailing an optional second output asset
  // @param uint256 inputValue, the total amount input, if there are two input assets, equal amounts of both assets will have been input
  // @param uint256 interactionNonce a globally unique identifier for this DeFi interaction. This is used as the assetId if one of the output assets is virtual
  // @param uint64 auxData other data to be passed into the bridge contract (slippage / nftID etc)
  // @return uint256 outputValueA the amount of outputAssetA returned from this interaction, should be 0 if async
  // @return uint256 outputValueB the amount of outputAssetB returned from this interaction, should be 0 if async or bridge only returns 1 asset.
  // @return bool isAsync a flag to toggle if this bridge interaction will return assets at a later date after some third party contract has interacted with it via finalise()
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
      uint256 outputValueA,
      uint256,
      bool isAsync
    )
  {
    require(msg.sender == rollupProcessor, "CowswapBridge: INVALID_CALLER");

    //GPv2VaultRelayer address on Mainnet:0xc92e8bdf79f0507f65a392b0ab4667716bfe0110
    require(
      IERC20(inputAssetA.erc20Address).approve(address(vaultRelayer), inputValue),
      "CowswapBridge: APPROVE_FAILED"
    );

    // place order on cowswap
    Types.CowswapOrder memory order = placeOrder(inputAssetA.erc20Address, outputAssetA.erc20Address, inputValue);
    require(bytes(order.orderUid).length > 0, "CowswapBridge: PLACE_ORDER_FAILED");
    interactions[interactionNonce] =  Types.Interaction(order.orderUid, order.sellAmount);
    
    // check interaction can be finalised
    for (uint256 i = 0; i < interactionNonces.length; i++) {
      Types.Interaction memory interaction = interactions[interactionNonces[i]];
      bool isFilled = isOrderFilled(interaction.orderUid, interaction.sellAmount);
      if (isFilled == true) {
        // Inform the rollup contract to finalise
        IRollupProcessor(rollupProcessor).processAsyncDeFiInteraction(interactionNonces[i]);
      }
    }

    return (0,0,true);
  }

  // @dev This function is called to check status of Interaction of specific interactionNonce.
  function canFinalise(
    uint256 interactionNonce
  ) external view override returns (bool isFilled) 
  {
     Types.Interaction memory interaction = interactions[interactionNonce];
    isFilled= isOrderFilled(interaction.orderUid, interaction.sellAmount);

    return isFilled;
  }


  // @dev This function is called from the RollupProcessor.sol contract via the DefiBridgeProxy. It receives the aggreagte sum of all users funds for the input assets.
  // @param AztecAsset inputAssetA a struct detailing the first input asset, this will always be set
  // @param AztecAsset inputAssetB an optional struct detailing the second input asset, this is used for repaying borrows and should be virtual
  // @param AztecAsset outputAssetA a struct detailing the first output asset, this will always be set
  // @param AztecAsset outputAssetB a struct detailing an optional second output asset
  // @param uint256 interactionNonce
  // @param uint64 auxData other data to be passed into the bridge contract (slippage / nftID etc)
  // @return uint256 outputValueA the return value of output asset A
  // @return uint256 outputValueB optional return value of output asset B
  // @dev this function should have a modifier on it to ensure it can only be called by the Rollup Contract
  function finalise(
    Types.AztecAsset calldata outputAssetA,
    Types.AztecAsset calldata,
    Types.AztecAsset calldata,
    Types.AztecAsset calldata,
    uint256 interactionNonce,
    uint64
  ) external payable override returns (uint256 outputValueA, uint256) 
  {
    require(msg.sender == rollupProcessor, "CowswapBridge: INVALID_CALLER");
    
     Types.Interaction memory interaction = interactions[interactionNonce];

    // A notifier will monitor settled trades, and save output amount for orderUid.
    outputValueA = outputAmounts[interaction.orderUid];

    // approve the transfer of token back to the rollup contract
    IERC20(outputAssetA.erc20Address).approve(rollupProcessor, outputValueA);

    //delete finilised interaction
    delete interactions[interactionNonce];
    removeInteractionNouce(interactionNonce);

    return (outputValueA,0);
  }
  
  /// @dev Place order on cowswap
  /// 
  /// Find a match presigned match order and call setPreSignature to activate order. 
  /// More detail on presigned order:
  /// https://docs.cow.fi/tutorials/cowswap-trades-with-a-gnosis-safe-wallet
  /// @param sellToken address of Token to sell
  /// @param buyToken address of Token to buy
  /// @param sellAmount amount of Token to sell

  function placeOrder(address sellToken, address buyToken, uint256 sellAmount) 
    private returns (Types.CowswapOrder memory)
  {
    // find a match order from presigned orders and presign
    for (uint256 i = 0; i < presignedOrders.length; i++) {
      Types.CowswapOrder memory order = presignedOrders[i];
      if (sellToken == order.sellToken && buyToken == order.buyToken && sellAmount == order.sellAmount) {
        cowswapSettlement.setPreSignature(order.orderUid, true);
        removeOrder(i);  // remove current order from presignedOrders
        return order;
      } 
    }
  }

  /// @dev Check if sellAmount of order filled
  /// 
  /// If order is completely filled, filledAmount[orderUid] will be same as total sell amount
  /// Refer to: https://github.com/gnosis/gp-v2-contracts/blob/main/src/contracts/GPv2Settlement.sol#L217
  /// @param orderUid The unique identifiers of the order
  function isOrderFilled(bytes memory orderUid, uint256 amount)
    private view returns (bool isFilled)
  {
      uint256 filledAmount = cowswapSettlement.filledAmount(orderUid);

      if(amount == filledAmount) {
        isFilled = true;
      } else {
        isFilled = false;
      }
      
      return isFilled;
  }

  /// @dev Remove order from presignedOrders array 
  /// 
  /// Should remove if presigned order get signed and activated
  function removeOrder(uint index) private 
  {
    require(index < presignedOrders.length, "index out if bound");

    for (uint256 i = index; i < presignedOrders.length - 1; i++) {
      presignedOrders[i] = presignedOrders[i + 1];   
    }
    presignedOrders.pop();
  }

  /// @dev Remove interactionNonce from interactionNonces array 
  /// 
  /// Should remove after interaction gets finalised
  function removeInteractionNouce(uint256 interactionNonce) private 
  {
    uint256 index = 2**256 - 1 ;

    for (uint256 i = 0; i < interactionNonces.length; i++) {
      if (i == interactionNonce) {
        index = i;
        break;
      }
    }

    require(index != 2**256 - 1, "element not exist");
    require(index < interactionNonces.length, "index out if bound");

    for (uint256 i = index; i < interactionNonces.length - 1; i++) {
      interactionNonces[i] = interactionNonces[i + 1];   
    }
    interactionNonces.pop();
  }
}
