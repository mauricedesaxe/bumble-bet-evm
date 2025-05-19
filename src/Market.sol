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

        Order storage order1 = orders[_user1][_orderId1];
        Order storage order2 = orders[_user2][_orderId2];

        if (order1.status != OrderStatus.PENDING || order2.status != OrderStatus.PENDING) {
            revert("Cannot match non-pending orders");
        }

        if (_isBuySell(order1, order2)) {
            if (!_isYesYes(order1, order2) && !_isNoNo(order1, order2)) {
                revert("Need to be yes-yes or no-no to match buy-sell orders");
            }

            // TODO: check if seller has enough shares
            // TODO: order size check / partials fills / etc
            // TODO: price check
            // TODO: transfer money to seller

            // transfer shares
            shares[order1.user][order1.yesNo] += order1.amount;
            shares[order2.user][order2.yesNo] -= order2.amount;

            // TODO: update order status
        } else if (_isBuyBuy(order1, order2)) {
            if (!_isYesNo(order1, order2)) {
                revert("Need to be yes-no to match buy-buy orders");
            }

            // TODO: order size check / partials fills / etc
            // TODO: price check
            // TODO: transfer money to vault

            // create shares
            shares[order1.user][order1.yesNo] += order1.amount;
            shares[order2.user][order2.yesNo] += order2.amount;

            // TODO: update order status
        } else {
            revert("Invalid order");
        }
    }

    function _isBuySell(Order storage order1, Order storage order2) internal view returns (bool) {
        if (order1.side == BuySell.BUY && order2.side == BuySell.SELL) {
            return true;
        }
        return false;
    }

    function _isBuyBuy(Order storage order1, Order storage order2) internal view returns (bool) {
        if (order1.side == BuySell.BUY && order2.side == BuySell.BUY) {
            return true;
        }
        return false;
    }

    function _isYesYes(Order storage order1, Order storage order2) internal view returns (bool) {
        if (order1.yesNo == YesNo.YES && order2.yesNo == YesNo.YES) {
            return true;
        }
        return false;
    }

    function _isNoNo(Order storage order1, Order storage order2) internal view returns (bool) {
        if (order1.yesNo == YesNo.NO && order2.yesNo == YesNo.NO) {
            return true;
        }
        return false;
    }

    function _isYesNo(Order storage order1, Order storage order2) internal view returns (bool) {
        if (order1.yesNo == YesNo.YES && order2.yesNo == YesNo.NO) {
            return true;
        }
        return false;
    }
}
