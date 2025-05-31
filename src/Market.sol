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
    uint256 shares;
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

    uint256 public immutable tokenDecimals;

    mapping(address => uint256) public orderCount;
    mapping(address => mapping(uint256 => Order)) public orders;
    mapping(address => mapping(MarketOutcome => uint256)) public shares;

    bool public resolved;
    MarketOutcome public outcome;

    // TODO: events

    constructor(string memory _name, address _paymentToken) {
        name = _name;
        owner = msg.sender;
        paymentToken = IERC20(_paymentToken);
        tokenDecimals = paymentToken.decimals();
    }

    /**
     * @notice Convert shares and price to token amount
     * @param _shares The number of shares to buy or sell
     * @param _price The price per share in cents (0-100, where 1% = 1 cent when using USD stablecoins)
     * @return The amount of tokens needed, accounting for token decimals
     * @dev When using USD stablecoins: price of 50 = 50 cents per share = $0.50 per share = 50% chance of your outcome
     * @dev At market resolution, winning shares pay out $1.00 (100 cents) each
     */
    function _convertAmountAndPriceToTokens(uint256 _shares, uint256 _price) internal view returns (uint256) {
        if (_shares == 0) {
            revert("Amount must be greater than zero");
        }

        if (_price == 0) {
            revert("Price must be greater than zero");
        }
        if (_price > 100) {
            revert("Price must be less than or equal to 100");
        }

        // Account for token decimals: shares * price * 10^decimals / 100
        // E.g.: 100 shares * 50 cents/% * 10^6 / 100 = 50 * 10^6 = 50,000,000 cents = 50.000000 USDC
        // E.g.: 100 shares * 50 cents/% * 10^18 / 100 = 50 * 10^18 = 5E19 cents = 50.000000000000000000 DAI
        return (_shares * _price * (10 ** tokenDecimals)) / 100;
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
     * @param _shares The amount of shares to buy or sell
     * @param _price The price of the shares
     */
    function createOrder(OrderSide _side, MarketOutcome _outcome, uint256 _shares, uint256 _price) public {
        if (resolved) {
            revert("Market is resolved");
        }

        if (_shares == 0) {
            revert("Amount must be greater than zero");
        }
        if (_price == 0) {
            revert("Price must be greater than zero");
        }

        uint256 totalCost = _convertAmountAndPriceToTokens(_shares, _price);

        if (_side == OrderSide.BUY) {
            // Check if buyer has enough token balance
            if (paymentToken.balanceOf(msg.sender) < totalCost) {
                revert("Insufficient balance");
            }

            // Transfer payment to contract for escrow
            paymentToken.transferFrom(msg.sender, address(this), totalCost);
        } else if (_side == OrderSide.SELL) {
            // check if user does have the shares to sell
            if (shares[msg.sender][_outcome] < _shares) {
                revert("Sell is not allowed if you don't own shares");
            }
        }

        orderCount[msg.sender]++;
        orders[msg.sender][orderCount[msg.sender]] = Order({
            user: msg.sender,
            shares: _shares,
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
            uint256 refundAmount = _convertAmountAndPriceToTokens(order.shares, order.price);
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
        if (resolved) {
            revert("Market is resolved");
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

        uint256 minShares = order1.shares < order2.shares ? order1.shares : order2.shares;
        uint256 maxShares = order1.shares > order2.shares ? order1.shares : order2.shares;

        if (minShares == 0 || maxShares == 0) {
            revert("Cannot match orders with zero amount");
        }

        if (OrderUtils.isBuySell(order1, order2)) {
            if (!OrderUtils.isYesYes(order1, order2) && !OrderUtils.isNoNo(order1, order2)) {
                revert("Need to be yes-yes or no-no to match buy-sell orders");
            }

            if (shares[order2.user][order2.yesNo] < minShares) {
                revert("Seller does not have enough shares");
            }

            // Price check for BUY-SELL orders
            if (order1.price < order2.price) {
                revert("BUY price below SELL price");
            }

            // Transfer payment to seller
            uint256 payment = _convertAmountAndPriceToTokens(minShares, order2.price); // Use seller's price
            paymentToken.transfer(order2.user, payment);

            // Transfer shares
            shares[order1.user][order1.yesNo] += minShares;
            shares[order2.user][order2.yesNo] -= minShares;

            if (minShares == maxShares) {
                order1.status = OrderStatus.FILLED;
                order2.status = OrderStatus.FILLED;
                order1.shares = 0;
                order2.shares = 0;

                // Refund excess to buyer if price difference and order is filled
                uint256 excessPrice = order1.price - order2.price;
                if (excessPrice > 0) {
                    uint256 refund = _convertAmountAndPriceToTokens(minShares, excessPrice);
                    if (refund > 0) {
                        paymentToken.transfer(order1.user, refund);
                    }
                }
            } else if (minShares == order1.shares) {
                order1.status = OrderStatus.FILLED;
                order1.shares = 0;
                order2.shares -= minShares;

                // Refund excess to buyer if price difference and order is filled
                uint256 excessPrice = order1.price - order2.price;
                if (excessPrice > 0) {
                    uint256 refund = _convertAmountAndPriceToTokens(minShares, excessPrice);
                    if (refund > 0) {
                        paymentToken.transfer(order1.user, refund);
                    }
                }
            } else {
                order2.status = OrderStatus.FILLED;
                order2.shares = 0;
                order1.shares -= minShares;

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
            shares[order1.user][order1.yesNo] += minShares;
            shares[order2.user][order2.yesNo] += minShares;

            if (minShares == maxShares) {
                order1.status = OrderStatus.FILLED;
                order2.status = OrderStatus.FILLED;
                order1.shares = 0;
                order2.shares = 0;
            } else if (minShares == order1.shares) {
                order1.status = OrderStatus.FILLED;
                order1.shares = 0;
                order2.shares -= minShares;

                // Keep the rest of buyer's payment in escrow for future matches
            } else {
                order2.status = OrderStatus.FILLED;
                order2.shares = 0;
                order1.shares -= minShares;

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
     */
    function claim() public {
        if (!resolved) {
            revert("Market is not resolved");
        }

        uint256 winningShares = shares[msg.sender][outcome];

        shares[msg.sender][MarketOutcome.YES] = 0;
        shares[msg.sender][MarketOutcome.NO] = 0;

        // Only transfer tokens if winner, but allow losers to claim so they clear their shares
        if (winningShares > 0) {
            // Winning shares pay out at 100 cents ($1.00) each
            uint256 payout = winningShares * (10 ** tokenDecimals);
            paymentToken.transfer(msg.sender, payout);
        }
    }
}
