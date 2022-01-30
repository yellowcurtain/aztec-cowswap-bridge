# Architecture

## Constrains

The main challenge of bridge is to place an off-chain order on Cowswap from on-chain smart contract, and get async response from Cowswap. 
The constrains of this bridge includes: 
  - It should be as decentralized as possible.
  - It should be compatible with current async workflow which also used on other decentralized exchange such as Uniswap.
  - It should expose same api to developer on Aztec, and require knowledge of Cowswap as little as possible. 
  - Bridge smart contract should be relatively stable and not require update regularly.
  - It should avoid use bot as much as possible to reduce the maintain work. 


## Workflow

<p align="center">
   <img src="https://github.com/yellowcurtain/aztec-cowswap-bridge/blob/main/images/bridge.png" alt="Bridge Workflow"/>
</p>

### Place order

With current Cowswap api, it is needed to get fee amount first and then place order. 

A possible solution could be using a relay server. 

Because Cowswap will support place order without fee in future, it could be a good idea to use a relay server which accept order without fee amount. And the relay server could get fee amount and then place order. 

By doing so, it is good for keeping CowswapBridge and Chainlink unchanged when Cowswap update its api.


### Get result

Get result from Cowswap is a bit tricky, because response from place order is order_id. It does not tell the status of order (fullfilled or pending), unless someone make another api call. 

For the case of Element Finance, to incentive any user to trigger withdraw is a good idea. 
For the case of Cowswap, it seems not so apporipit. 
And maintaining a bot is also not ideal. 

A hack could be like this:
Same as a reentrancy attack, after receiving token from Cowswap smart contract, it will trigger fallback funcion. In this function, it could start an api call to check status and trigger the rest of aysnc flow.

```bash
    fallback() external payable {
    }
```



