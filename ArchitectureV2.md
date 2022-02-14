# Architecture V2

## Goal

The main improvement of this version is that this version is more decentralized and secure.


## Workflow

<p align="center">
   <img src="https://github.com/yellowcurtain/aztec-cowswap-bridge/blob/main/images/bridgeV2.png" alt="Bridge Workflow"/>
</p>


### Place order

A 3rd party keeper is incentived to place presigned orders on Cowswap and keep an array of presigned orders on CowswapBridge.  
When user's order from Aztec comes, for example, swap 3500 USDC to 1ETH.  
CowswapBridge contract pick 1 order that swap 3000 USDC to ETH and 1 order that swap 500 USDC to ETH, then call settlement.setPreSignature(order_uid, True).


### Get result

Since order from Aztec layer should be quite often, a checkStatus function can be called every time to help previous orders get return result.

