// SPDX-License-Identifier: GPL-2.0-only
// Copyright 2020 Spilsbury Holdings Ltd
pragma solidity >=0.6.6 <0.8.0;
pragma experimental ABIEncoderV2;
interface IGPv2Settlement {

    // mapping(bytes => uint256) public filledAmount;
    // https://www.quicknode.com/guides/solidity/how-to-call-another-smart-contract-from-your-solidity-code
    function filledAmount(bytes calldata orderUid) external view returns (uint256);

    function setPreSignature(bytes calldata orderUid, bool signed) external;

}

