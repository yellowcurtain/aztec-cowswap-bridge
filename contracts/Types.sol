// SPDX-License-Identifier: GPL-2.0-only

pragma solidity >=0.6.10 <0.8.10;
pragma experimental ABIEncoderV2;

library Types {
    enum AztecAssetType {
        NOT_USED,
        ETH,
        ERC20,
        VIRTUAL
    }

    struct AztecAsset {
        uint256 id;
        address erc20Address;
        AztecAssetType assetType;
    }

    struct CowswapOrder {
        uint256 sellAmount; //pack variables
        uint256 buyAmount;
        uint256 feeAmount;
        address sellToken;
        address buyToken;
        uint32 validTo;
        bytes orderUid; //bytes is used in GPv2Settlement
    }

    struct Interaction {
        uint256 sellAmount; //pack variables
        uint256 buyAmount;
        address buyToken;
        bytes orderUid; //bytes is used in GPv2Settlement
    }

}
