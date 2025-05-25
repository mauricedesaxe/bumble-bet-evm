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

    // Constants for price precision
    uint256 public constant BASIS_POINTS = 100_00; // 100% = 100_00 basis points

    mapping(address => uint256) public orderCount;
    mapping(address => mapping(uint256 => Order)) public orders;
    mapping(address => mapping(MarketOutcome => uint256)) public shares;

    bool public resolved;
    MarketOutcome public outcome;

    uint8 public immutable paymentTokenDecimals;
    uint256 public constant SHARE_DECIMALS = 18;

    // TODO: events

    constructor(string memory _name, address _paymentToken) {
        name = _name;
        owner = msg.sender;
        paymentToken = IERC20(_paymentToken);
        paymentTokenDecimals = IERC20(_paymentToken).decimals();
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
     * @notice Convert share amounts with price to payment token amounts
     * @param _shareAmount The amount of shares (18 decimals)
     * @param _priceInBasisPoints The price in basis points (0-10000) or the chance of the outcome happening (0 - 100.00%)
     * @return The amount of payment tokens (paymentTokenDecimals decimals)
     */
    function calculatePaymentTokens(uint256 _shareAmount, uint256 _priceInBasisPoints)
        internal
        view
        returns (uint256)
    {
        // 1. Calculate the cost in share decimal units
        uint256 costInShareDecimals = (_shareAmount * _priceInBasisPoints) / BASIS_POINTS;

        // 2. Convert to payment token decimals
        if (SHARE_DECIMALS > paymentTokenDecimals) {
            return costInShareDecimals / (10 ** (SHARE_DECIMALS - paymentTokenDecimals));
        } else if (SHARE_DECIMALS < paymentTokenDecimals) {
            return costInShareDecimals * (10 ** (paymentTokenDecimals - SHARE_DECIMALS));
        }

        // 3. Reverse as a sanity check
        uint256 reverse = paymentTokensToShares(costInShareDecimals, _priceInBasisPoints);
        if (reverse != _shareAmount) {
            revert("Reverse calculation does not match");
        }

        return costInShareDecimals;
    }

    /**
     * @notice Convert payment token amounts to share amounts given a price
     * @param _paymentTokenAmount The amount of payment tokens (paymentTokenDecimals decimals)
     * @param _priceInBasisPoints The price in basis points (0-10000)
     * @return The amount of shares (18 decimals)
     */
    function paymentTokensToShares(uint256 _paymentTokenAmount, uint256 _priceInBasisPoints)
        internal
        view
        returns (uint256)
    {
        require(_priceInBasisPoints > 0, "Price must be greater than 0");

        // 1. Convert payment token amount to share decimals
        uint256 amountInShareDecimals;
        if (SHARE_DECIMALS > paymentTokenDecimals) {
            amountInShareDecimals = _paymentTokenAmount * (10 ** (SHARE_DECIMALS - paymentTokenDecimals));
        } else if (SHARE_DECIMALS < paymentTokenDecimals) {
            amountInShareDecimals = _paymentTokenAmount / (10 ** (paymentTokenDecimals - SHARE_DECIMALS));
        } else {
            amountInShareDecimals = _paymentTokenAmount;
        }

        // 2. Calculate shares: shares = (paymentAmount * BASIS_POINTS) / price
        // This reverses: paymentAmount = (shares * price) / BASIS_POINTS
        return (amountInShareDecimals * BASIS_POINTS) / _priceInBasisPoints;
    }

    /**
     * @notice Create an order to buy or sell shares of a market outcome.
     * @param _side The side of the order (buy or sell)
     * @param _outcome The outcome of the market (yes or no)
     * @param _amount The amount of shares to buy or sell (in share units with 18 decimals)
     * @param _price The price of the shares in basis points (0-10000, where 10000 = 100%)
     */
    function createOrder(OrderSide _side, MarketOutcome _outcome, uint256 _amount, uint256 _price) public {
        if (resolved) {
            revert("Market is already resolved");
        }

        if (_amount == 0) {
            revert("Amount must be greater than zero");
        }
        if (_price == 0 || _price > BASIS_POINTS) {
            revert("Price must be between 1 and 10000 basis points");
        }

        if (_side == OrderSide.BUY) {
            // Calculate total cost in payment tokens
            uint256 totalCost = calculatePaymentTokens(_amount, _price);

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
            uint256 refundAmount = calculatePaymentTokens(order.amount, order.price);
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
     *    - BUY-BUY: Requires opposite outcomes (order1=YES, order2=NO) and prices must sum to BASIS_POINTS.
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
        if (resolved) {
            revert("Market is already resolved");
        }

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

            // Transfer payment to seller using seller's price
            uint256 payment = calculatePaymentTokens(minAmount, order2.price);
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
                    uint256 refund = calculatePaymentTokens(minAmount, excessPrice);
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
                    uint256 refund = calculatePaymentTokens(minAmount, excessPrice);
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

            // Price check for BUY-BUY orders - prices must sum to BASIS_POINTS
            if (order1.price + order2.price != BASIS_POINTS) {
                revert("YES+NO prices must sum to 10000 basis points");
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

    /**
     * @notice Resolve the market.
     * @dev This is called by the owner to resolve the market.
     * @param _outcome The outcome of the market (yes or no)
     */
    function resolveMarket(MarketOutcome _outcome) public {
        if (resolved) {
            revert("Market is already resolved");
        }

        if (msg.sender != owner) {
            revert("Only the owner can resolve the market");
        }

        resolved = true;
        outcome = _outcome;
    }

    /**
     * @notice Claim the outcome of the market.
     * @dev This is called by the user to claim their shares after the market is resolved.
     * @dev Winning shares are redeemed 1:1 for payment tokens
     */
    function claim() public {
        if (!resolved) {
            revert("Market is not resolved");
        }

        uint256 winningShares = shares[msg.sender][outcome];
        if (winningShares == 0) {
            revert("No shares to claim");
        }

        shares[msg.sender][MarketOutcome.YES] = 0;
        shares[msg.sender][MarketOutcome.NO] = 0;

        // Winning shares are redeemed 1:1 (100% price)
        uint256 payout = calculatePaymentTokens(winningShares, BASIS_POINTS);
        paymentToken.transfer(msg.sender, payout);
    }
}
