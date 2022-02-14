import time
import requests


def presign():
    
    # get the fee + the buy amount after fee
    fee_and_quote = "https://protocol-xdai.gnosis.io/api/v1/feeAndQuote/sell"
    get_params = {
        "sellToken": sell_token_address,
        "buyToken": buy_token_address,
        "sellAmountBeforeFee": sell_amount_mul_decimals
    }
    r = requests.get(fee_and_quote, params=get_params)
    assert r.ok and r.status_code == 200
    
    # These two values are needed to create an order
    fee_amount = int(r.json()['fee']['amount'])
    buy_amount_after_fee = int(r.json()['buyAmountAfterFee'])
    assert fee_amount > 0
    assert buy_amount_after_fee > 0

    # Pretty random order deadline
    deadline = int(time.time()) + 60*60*24 # 1 day

    # Submit order
    order_payload = {
        "sellToken": sell_token_address,
        "buyToken": buy_token_address,
        "sellAmount": str(sell_amount_mul_decimals - fee_amount), # amount that we have minus the fee we have to pay
        "buyAmount": str(buy_amount_after_fee), # buy amount fetched from the previous call
        "validTo": deadline,
        "appData": "0x2B8694ED30082129598720860E8E972F07AA10D9B81CAE16CA0E2CFB24743E24",
        "feeAmount": str(fee_amount),
        "kind": "sell",
        "partiallyFillable": False,
        "receiver": bridge_address,
        "signature": bridge_address,
        "from": bridge_address,
        "sellTokenBalance": "erc20",
        "buyTokenBalance": "erc20",
        "signingScheme": "presign"
    }
    orders_url = f"https://protocol-xdai.gnosis.io/api/v1/orders"
    r = requests.post(orders_url, json=order_payload)
    assert r.ok and r.status_code == 201
    order_uid = r.json()
    print(f"Payload: {order_payload}")
    print(f"Order uid: {order_uid}")



#### START HERE ####
tokens = {
    "0xddafbb505ad214d7b80b1f830fccc89b60fb7a83": {'symbol': 'USDC', 'address': '0xddafbb505ad214d7b80b1f830fccc89b60fb7a83', 'decimals': 6},
    "0xe91d153e0b41518a2ce8dd3d7944fa863463a97d": {'symbol': 'wxDAI', 'address': '0xe91d153e0b41518a2ce8dd3d7944fa863463a97d', 'decimals': 18} 
}

sell_token_address = "0xe91d153e0b41518a2ce8dd3d7944fa863463a97d" #wxDai
buy_token_address = "0xddafbb505ad214d7b80b1f830fccc89b60fb7a83"  #USDC
sell_token_decimals = tokens[sell_token_address]["decimals"]
buy_token_decimals = tokens[buy_token_address]["decimals"]

sell_amount = 1
sell_amount_mul_decimals = sell_amount * 10**sell_token_decimals

bridge_address = "" #TODO

presign()
