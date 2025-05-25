// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {OrderUtils} from "./OrderUtils.sol";
import {IERC20} from "./interfaces/IERC20.sol";

enum OrderSide {
    BUY,
    SELL
}

enum MarketOutcome {
    YES,
    NO
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
    OrderSide side;
    MarketOutcome yesNo;
    OrderStatus status;
}

/**
 * @title Market
 * @notice This contract is a simple market for buying and selling shares of a market outcome.
 * @notice We only handle limit orders for now because it's simpler. If you need market orders,
 * @notice you can look up the state on-chain and create an order with a price and size that matches
 * @notice what is in the orderbook. That will be immediately fill-able by `matchOrders`.
 * @dev This contract is not audited, use at your own risk.
 */
contract Market {
    using OrderUtils for Order;

    string public name;
    address public owner;
    IERC20 public paymentToken;

    mapping(address => uint256) public orderCount;
    mapping(address => mapping(uint256 => Order)) public orders;
    mapping(address => mapping(MarketOutcome => uint256)) public shares;

    constructor(string memory _name, address _paymentToken) {
        name = _name;
        owner = msg.sender;
        paymentToken = IERC20(_paymentToken);
    }

    /**
     * @notice Set the name of the market if you need to change it later.
     * @param _name The new name of the market
     */
    function setName(string memory _name) public {
        if (msg.sender != owner) {
            revert("Only the owner can set the name");
        }
        name = _name;
    }

    /**
     * @notice Create an order to buy or sell shares of a market outcome.
     * @param _side The side of the order (buy or sell)
     * @param _outcome The outcome of the market (yes or no)
     * @param _amount The amount of shares to buy or sell
     * @param _price The price of the shares
     */
    function createOrder(OrderSide _side, MarketOutcome _outcome, uint256 _amount, uint256 _price) public {
        if (_amount == 0) {
            revert("Amount must be greater than zero");
        }
        if (_price == 0) {
            revert("Price must be greater than zero");
        }

        uint256 totalCost = _amount * _price / 100;

        if (_side == OrderSide.BUY) {
            // Check if buyer has enough token balance
            if (paymentToken.balanceOf(msg.sender) < totalCost) {
                revert("Insufficient balance");
            }

            // Transfer payment to contract for escrow
            paymentToken.transferFrom(msg.sender, address(this), totalCost);
        } else if (_side == OrderSide.SELL) {
            // check if user does have the shares to sell
            if (shares[msg.sender][_outcome] < _amount) {
                revert("Sell is not allowed if you don't own shares");
            }
        }

        orderCount[msg.sender]++;
        orders[msg.sender][orderCount[msg.sender]] = Order({
            user: msg.sender,
            amount: _amount,
            price: _price,
            side: _side,
            yesNo: _outcome,
            status: OrderStatus.PENDING
        });
    }

    /**
     * @notice Cancel an order.
     * @dev If the order is one the buy side, the user will get their payment back.
     * @param _orderId The id of the order to cancel
     */
    function cancelOrder(uint256 _orderId) public {
        Order storage order = orders[msg.sender][_orderId];
        if (order.user == address(0)) {
            revert("Order does not exist");
        }

        if (order.status != OrderStatus.PENDING) {
            revert("Cannot cancel a non-pending order");
        }

        // Return escrowed funds if it was a buy order
        if (order.side == OrderSide.BUY) {
            uint256 refundAmount = order.amount * order.price / 100;
            paymentToken.transfer(msg.sender, refundAmount);
        }

        order.status = OrderStatus.CANCELLED;
    }

    /**
     * @notice Attempt to match two orders.
     * @dev This is possibly the single most important function in the contract.
     * @dev It is called by the owner to match two orders.
     *
     * Execution Flow:
     * 1. Validate caller is owner and users are different
     * 2. Load both orders and verify they exist and are PENDING
     * 3. Calculate fill amount (minimum of both order amounts)
     * 4. Route to appropriate matching logic:
     *    - BUY-SELL: Requires order1=BUY, order2=SELL with same outcome (YES-YES or NO-NO).
     *      Validates seller has shares, buyer price >= seller price, transfers payment to seller,
     *      transfers shares to buyer, refunds excess escrow to buyer if price difference exists.
     *    - BUY-BUY: Requires opposite outcomes (order1=YES, order2=NO) and prices must sum to 100.
     *      Creates new shares for both users (both have already paid into escrow when creating orders).
     * 5. Update order amounts and set status to FILLED if fully matched
     * 6. Handle partial fills by keeping remaining amounts in escrow for future matches
     *
     * @param _user1 The user of the first order (buyer in BUY-SELL scenarios)
     * @param _user2 The user of the second order (seller in BUY-SELL scenarios)
     * @param _orderId1 The id of the first order
     * @param _orderId2 The id of the second order
     */
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

            // Transfer payment to seller
            uint256 payment = minAmount * order2.price / 100; // Use seller's price
            paymentToken.transfer(order2.user, payment);

            // Transfer shares
            shares[order1.user][order1.yesNo] += minAmount;
            shares[order2.user][order2.yesNo] -= minAmount;

            if (minAmount == maxAmount) {
                order1.status = OrderStatus.FILLED;
                order2.status = OrderStatus.FILLED;
                order1.amount = 0;
                order2.amount = 0;

                // Refund excess to buyer if price difference and order is filled
                uint256 excessPrice = order1.price - order2.price;
                if (excessPrice > 0) {
                    uint256 refund = minAmount * excessPrice / 100;
                    if (refund > 0) {
                        paymentToken.transfer(order1.user, refund);
                    }
                }
            } else if (minAmount == order1.amount) {
                order1.status = OrderStatus.FILLED;
                order1.amount = 0;
                order2.amount -= minAmount;

                // Refund excess to buyer if price difference and order is filled
                uint256 excessPrice = order1.price - order2.price;
                if (excessPrice > 0) {
                    uint256 refund = minAmount * excessPrice / 100;
                    if (refund > 0) {
                        paymentToken.transfer(order1.user, refund);
                    }
                }
            } else {
                order2.status = OrderStatus.FILLED;
                order2.amount = 0;
                order1.amount -= minAmount;

                // Keep the rest of buyer's payment in escrow for future matches
            }
        } else if (OrderUtils.isBuyBuy(order1, order2)) {
            if (!OrderUtils.isYesNo(order1, order2)) {
                revert("Need to be yes-no to match buy-buy orders");
            }

            // Price check for BUY-BUY orders
            if (order1.price + order2.price != 100) {
                revert("YES+NO prices must sum to 100");
            }

            // Both orders have already paid into escrow, so no further transfers needed

            // Create shares
            shares[order1.user][order1.yesNo] += minAmount;
            shares[order2.user][order2.yesNo] += minAmount;

            if (minAmount == maxAmount) {
                order1.status = OrderStatus.FILLED;
                order2.status = OrderStatus.FILLED;
                order1.amount = 0;
                order2.amount = 0;
            } else if (minAmount == order1.amount) {
                order1.status = OrderStatus.FILLED;
                order1.amount = 0;
                order2.amount -= minAmount;

                // Keep the rest of buyer's payment in escrow for future matches
            } else {
                order2.status = OrderStatus.FILLED;
                order2.amount = 0;
                order1.amount -= minAmount;

                // Keep the rest of buyer's payment in escrow for future matches
            }
        } else {
            revert("Invalid order");
        }
    }
}
