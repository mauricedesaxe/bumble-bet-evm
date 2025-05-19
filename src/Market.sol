// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

enum BuySell {
    BUY,
    SELL
}

enum YesNo {
    YES,
    NO
}

enum LimitMarket {
    LIMIT,
    MARKET
}

enum OrderStatus {
    PENDING,
    FILLED,
    CANCELLED
}

struct Order {
    address user;
    uint256 amount;
    uint256 price;
    BuySell side;
    YesNo yesNo;
    LimitMarket limitMarket;
    OrderStatus status;
}

contract Market {
    string public name;
    address public owner;

    mapping(address => uint256) public orderCount;
    mapping(address => mapping(uint256 => Order)) public orders;

    constructor(string memory _name) {
        name = _name;
        owner = msg.sender;
    }

    function setName(string memory _name) public {
        if (msg.sender != owner) {
            revert("Only the owner can set the name");
        }
        name = _name;
    }

    function createOrder(BuySell _side, YesNo _yesNo, LimitMarket _limitMarket, uint256 _amount, uint256 _price)
        public
    {
        if (_amount == 0) {
            revert("Amount must be greater than zero");
        }
        if (_price == 0) {
            revert("Price must be greater than zero");
        }

        if (_side == BuySell.SELL) {
            // TODO check if user does have the balance to sell
            revert("Sell is not allowed if you don't own shares");
        }

        orderCount[msg.sender]++;
        orders[msg.sender][orderCount[msg.sender]] = Order({
            user: msg.sender,
            amount: _amount,
            price: _price,
            side: _side,
            yesNo: _yesNo,
            limitMarket: _limitMarket,
            status: OrderStatus.PENDING
        });
    }
}
