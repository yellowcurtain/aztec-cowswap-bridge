# Aztec Cowswap Bridge

#### How does this work?

Users who have shielded assets on Aztec can construct a zero-knowledge proof instructing the Aztec rollup contract to make an external L1 contract call.

Rollup providers batch multiple L2 transaction intents on the Aztec Network together in a rollup. The rollup contract then makes aggregate transaction against L1 DeFi contracts and returns the funds pro-rata to the users on L2.

 
### Async flow explainer

If a Defi Bridge interaction is asynchronous, it must be finalised at a later date once the DeFi interaction has completed.

This is acheived by calling `RollupProcessor.processAsyncDefiInteraction(uint256 interactionNonce)`. This internally will call finalise and ensure the correct amount of tokens have been transferred.

#### convert()

This function is called from the Aztec Rollup Contract via the DeFi Bridge Proxy. Before this function on your bridge contract is called the rollup contract will have sent you ETH or Tokens defined by the input params.

This function should interact with the DeFi protocol e.g Uniswap, and transfer tokens or ETH back to the Aztec Rollup Contract. The Rollup contract will check it received the correct amount.

If the DeFi interaction is ASYNC i.e it does not settle in the same block, the call to convert should return (0,0 true). The contract should record the interaction nonce for any Async position or if virtual assets are returned.

At a later date, this interaction can be finalised by proding the rollup contract to call finalise on the bridge.

#### canFinalise()

This function checks to see if an async interaction is ready to settle. It should return true if it is.

#### function finalise()

This function will be called from the Azte Rollup contract. The Aztec rollup contract will check that it received the correct amount of ETH and Tokens specified by the return values, and trigger the settlement step on Aztec.

#### TODO

- cowswap onchain access, cowswap.sol
- deploy script, deploy_cowswap.ts
- test script, cowswap_bridge.test.ts
