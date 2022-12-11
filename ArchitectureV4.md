# Architecture V4

## Goal

The main challenge of bridge is to place an off-chain order on Cowswap from on-chain smart contract, and get async response from Cowswap.
With Cowswap's new feature, being able to place an on-chain order with 0 fee, the workflow becomes simpler.


## Workflow of CowswapBridge

<p align="center">
   <img src="https://github.com/yellowcurtain/aztec-cowswap-bridge/blob/main/images/bridgeV4.png" alt="Bridge Workflow"/>
</p>

Users who have shielded assets on Aztec can construct a zero-knowledge proof instructing the Aztec rollup contract to make an external L1 contract call. Rollup providers batch multiple L2 transaction intents on the Aztec Network together in a rollup. The rollup contract then makes aggregate transaction against L1 Cowswap contracts and later returns the funds to the users on L2.

1. To start workflow, Aztec rollup contract calls `RollupProcessor.processAsyncDefiInteraction(uint256 interactionNonce)`, and sends ETH or Tokens defined by the input params to CowswapBridge contract.
2. CowswapBridge contract calls `convert()`. In `convert()` function, it approves Cowswap contract to spend input tokens and places order on Cowswap.
3. Because of Cowswap's design, CowswapBridge interaction is asynchronous. CowswapBridge contract checks previous pending transactions. If there are pending transactions that has completed yet not finalized, CowswapBridge contract calls `finalise()`.
4. `finalise()` ensure the correct amount of tokens transfer to Aztec rollup contract.


## Workflow of Aztec Rollup

1. Users' cryptographic value notes on L2 are destroyed, and they receive cryptographic claim notes which make them eligible for the results of the interaction (output tokens),
2. `rollup provider` creates a rollup block and sends it to the `RollupProcessor` contract (the rollup block contains the corresponding bridge call),
3. `RollupProcessor` calls `DefiBridgeProxy`'s `convert(...)` function via delegate call (input and output assets are of `ERC20` type),
4. `DefiBridgeProxy` contract transfers `totalInputValue` of input tokens to the `bridge`,
5. `DefiBridgeProxy` calls the `bridge`'s convert function,
6. in the convert function `bridge` approves `RollupProcessor` to spend `outputValue[A,B]` of output tokens,
7. `DefiBridgeProxy` pulls the `outputValue[A,B]` of output tokens to `RollupProcessor`,
8. once the interaction is finished `rollup provider` submits a claim on behalf of each user who partook in the interaction (claim note is destroyed and new value note is created).




