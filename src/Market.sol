// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {OrderUtils} from "./OrderUtils.sol";

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
    using OrderUtils for Order;

    string public name;
    address public owner;

    mapping(address => uint256) public orderCount;
    mapping(address => mapping(uint256 => Order)) public orders;
    mapping(address => mapping(YesNo => uint256)) public shares;

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
            // check if user does have the shares to sell
            if (shares[msg.sender][_yesNo] < _amount) {
                revert("Sell is not allowed if you don't own shares");
            }
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

    function cancelOrder(uint256 _orderId) public {
        Order storage order = orders[msg.sender][_orderId];
        if (order.user == address(0)) {
            revert("Order does not exist");
        }

        if (order.status != OrderStatus.PENDING) {
            revert("Cannot cancel a non-pending order");
        }

        order.status = OrderStatus.CANCELLED;
    }

    function matchOrders(address _user1, address _user2, uint256 _orderId1, uint256 _orderId2) public {
        if (msg.sender != owner) {
            revert("Only the owner can match orders");
        }

        if (_user1 == _user2) {
            revert("Cannot match orders for the same user");
        }

        Order storage order1 = orders[_user1][_orderId1];
        Order storage order2 = orders[_user2][_orderId2];
        if (order1.user == address(0) || order2.user == address(0)) {
            revert("Order does not exist");
        }

        if (order1.status != OrderStatus.PENDING || order2.status != OrderStatus.PENDING) {
            revert("Cannot match non-pending orders");
        }

        uint256 minAmount = order1.amount < order2.amount ? order1.amount : order2.amount;
        uint256 maxAmount = order1.amount > order2.amount ? order1.amount : order2.amount;

        if (minAmount == 0 || maxAmount == 0) {
            revert("Cannot match orders with zero amount");
        }

        if (OrderUtils.isBuySell(order1, order2)) {
            if (!OrderUtils.isYesYes(order1, order2) && !OrderUtils.isNoNo(order1, order2)) {
                revert("Need to be yes-yes or no-no to match buy-sell orders");
            }

            if (shares[order2.user][order2.yesNo] < minAmount) {
                revert("Seller does not have enough shares");
            }

            // Price check for BUY-SELL orders
            if (order1.price < order2.price) {
                revert("BUY price below SELL price");
            }

            // TODO: transfer money to seller

            // transfer shares
            shares[order1.user][order1.yesNo] += minAmount;
            shares[order2.user][order2.yesNo] -= minAmount;

            if (minAmount == maxAmount) {
                order1.status = OrderStatus.FILLED;
                order2.status = OrderStatus.FILLED;
            } else if (minAmount == order1.amount) {
                order1.status = OrderStatus.FILLED;
                order2.amount -= minAmount;
            } else {
                order2.status = OrderStatus.FILLED;
                order1.amount -= minAmount;
            }
        } else if (OrderUtils.isBuyBuy(order1, order2)) {
            if (!OrderUtils.isYesNo(order1, order2)) {
                revert("Need to be yes-no to match buy-buy orders");
            }

            // Price check for BUY-BUY orders
            if (order1.price + order2.price != 100) {
                revert("YES+NO prices must sum to 100");
            }

            // TODO: transfer money to vault

            // create shares
            shares[order1.user][order1.yesNo] += minAmount;
            shares[order2.user][order2.yesNo] += minAmount;

            if (minAmount == maxAmount) {
                order1.status = OrderStatus.FILLED;
                order2.status = OrderStatus.FILLED;
            } else if (minAmount == order1.amount) {
                order1.status = OrderStatus.FILLED;
                order2.amount -= minAmount;
            } else {
                order2.status = OrderStatus.FILLED;
                order1.amount -= minAmount;
            }
        } else {
            revert("Invalid order");
        }
    }
}
