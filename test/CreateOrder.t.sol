// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Market, BuySell, LimitMarket, YesNo, OrderStatus, Order} from "../src/Market.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {MockERC20} from "../src/__mocks__/MockERC20.sol";

contract MarketTest is Test {
    IERC20 public token;
    Market public market;

    function setUp() public {
        token = IERC20(address(new MockERC20("Token", "TKN")));
        market = new Market("Market", address(token));

        // Set up token balances
        token.mint(address(this), 100 ether);

        // Set up token allowances
        token.approve(address(market), 100 ether);
    }

    // BUY-YES-LIMIT
    function testFuzz_Market_CreateOrder_BuyYesLimit(uint256 amount, uint256 price) public {
        // Limit values to reasonable ranges to avoid overflow and insufficient balance
        price = bound(price, 1, 99); // 100%
        amount = bound(amount, 1, 100 ether * 100 / price);

        uint256 balanceBefore = token.balanceOf(address(this));
        uint256 marketBalanceBefore = token.balanceOf(address(market));

        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, amount, price);
        assertEq(market.orderCount(address(this)), 1);

        uint256 balanceAfter = token.balanceOf(address(this));
        uint256 marketBalanceAfter = token.balanceOf(address(market));

        assertEq(balanceAfter, balanceBefore - amount * price / 100);
        assertEq(marketBalanceAfter, marketBalanceBefore + amount * price / 100);

        (
            address user,
            uint256 orderAmount,
            uint256 orderPrice,
            BuySell side,
            YesNo yesNo,
            LimitMarket limitMarket,
            OrderStatus status
        ) = market.orders(address(this), 1);

        assertEq(user, address(this));
        assertEq(uint256(side), uint256(BuySell.BUY));
        assertEq(uint256(yesNo), uint256(YesNo.YES));
        assertEq(uint256(limitMarket), uint256(LimitMarket.LIMIT));
        assertEq(orderAmount, amount);
        assertEq(orderPrice, price);
        assertEq(uint256(status), uint256(OrderStatus.PENDING));
    }

    // BUY-YES-MARKET
    function testFuzz_Market_CreateOrder_BuyYesMarket(uint256 amount, uint256 price) public {
        // Limit values to reasonable ranges to avoid overflow and insufficient balance
        price = bound(price, 1, 99); // 100%
        amount = bound(amount, 1, 100 ether * 100 / price);

        uint256 balanceBefore = token.balanceOf(address(this));
        uint256 marketBalanceBefore = token.balanceOf(address(market));

        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.MARKET, amount, price);
        assertEq(market.orderCount(address(this)), 1);

        uint256 balanceAfter = token.balanceOf(address(this));
        uint256 marketBalanceAfter = token.balanceOf(address(market));

        assertEq(balanceAfter, balanceBefore - amount * price / 100);
        assertEq(marketBalanceAfter, marketBalanceBefore + amount * price / 100);

        (
            address user,
            uint256 orderAmount,
            uint256 orderPrice,
            BuySell side,
            YesNo yesNo,
            LimitMarket limitMarket,
            OrderStatus status
        ) = market.orders(address(this), 1);

        assertEq(user, address(this));
        assertEq(uint256(side), uint256(BuySell.BUY));
        assertEq(uint256(yesNo), uint256(YesNo.YES));
        assertEq(uint256(limitMarket), uint256(LimitMarket.MARKET));
        assertEq(orderAmount, amount);
        assertEq(orderPrice, price);
        assertEq(uint256(status), uint256(OrderStatus.PENDING));
    }

    // BUY-NO-LIMIT
    function testFuzz_Market_CreateOrder_BuyNoLimit(uint256 amount, uint256 price) public {
        // Limit values to reasonable ranges to avoid overflow and insufficient balance
        price = bound(price, 1, 99); // 100%
        amount = bound(amount, 1, 100 ether * 100 / price);

        uint256 balanceBefore = token.balanceOf(address(this));
        uint256 marketBalanceBefore = token.balanceOf(address(market));

        market.createOrder(BuySell.BUY, YesNo.NO, LimitMarket.LIMIT, amount, price);
        assertEq(market.orderCount(address(this)), 1);

        uint256 balanceAfter = token.balanceOf(address(this));
        uint256 marketBalanceAfter = token.balanceOf(address(market));

        assertEq(balanceAfter, balanceBefore - amount * price / 100);
        assertEq(marketBalanceAfter, marketBalanceBefore + amount * price / 100);

        (
            address user,
            uint256 orderAmount,
            uint256 orderPrice,
            BuySell side,
            YesNo yesNo,
            LimitMarket limitMarket,
            OrderStatus status
        ) = market.orders(address(this), 1);

        assertEq(user, address(this));
        assertEq(uint256(side), uint256(BuySell.BUY));
        assertEq(uint256(yesNo), uint256(YesNo.NO));
        assertEq(uint256(limitMarket), uint256(LimitMarket.LIMIT));
        assertEq(orderAmount, amount);
        assertEq(orderPrice, price);
        assertEq(uint256(status), uint256(OrderStatus.PENDING));
    }

    // BUY-NO-MARKET
    function testFuzz_Market_CreateOrder_BuyNoMarket(uint256 amount, uint256 price) public {
        // Limit values to reasonable ranges to avoid overflow and insufficient balance
        price = bound(price, 1, 99); // 100%
        amount = bound(amount, 1, 100 ether * 100 / price);

        uint256 balanceBefore = token.balanceOf(address(this));
        uint256 marketBalanceBefore = token.balanceOf(address(market));

        market.createOrder(BuySell.BUY, YesNo.NO, LimitMarket.MARKET, amount, price);
        assertEq(market.orderCount(address(this)), 1);

        uint256 balanceAfter = token.balanceOf(address(this));
        uint256 marketBalanceAfter = token.balanceOf(address(market));

        assertEq(balanceAfter, balanceBefore - amount * price / 100);
        assertEq(marketBalanceAfter, marketBalanceBefore + amount * price / 100);
    }

    // SELL-YES-LIMIT (should revert)
    function testFuzz_Market_CreateOrder_SellYesLimit(uint256 amount, uint256 price) public {
        // Limit values to reasonable ranges to avoid overflow and insufficient balance
        price = bound(price, 1, 99); // 100%
        amount = bound(amount, 1, 100 ether * 100 / price);

        vm.expectRevert("Sell is not allowed if you don't own shares");
        market.createOrder(BuySell.SELL, YesNo.YES, LimitMarket.LIMIT, amount, price);
    }

    // SELL-YES-MARKET (should revert)
    function testFuzz_Market_CreateOrder_SellYesMarket(uint256 amount, uint256 price) public {
        // Limit values to reasonable ranges to avoid overflow and insufficient balance
        price = bound(price, 1, 99); // 100%
        amount = bound(amount, 1, 100 ether * 100 / price);

        vm.expectRevert("Sell is not allowed if you don't own shares");
        market.createOrder(BuySell.SELL, YesNo.YES, LimitMarket.MARKET, amount, price);
    }

    // SELL-NO-LIMIT (should revert)
    function testFuzz_Market_CreateOrder_SellNoLimit(uint256 amount, uint256 price) public {
        // Limit values to reasonable ranges to avoid overflow and insufficient balance
        price = bound(price, 1, 99); // 100%
        amount = bound(amount, 1, 100 ether * 100 / price);

        vm.expectRevert("Sell is not allowed if you don't own shares");
        market.createOrder(BuySell.SELL, YesNo.NO, LimitMarket.LIMIT, amount, price);
    }

    // SELL-NO-MARKET (should revert)
    function testFuzz_Market_CreateOrder_SellNoMarket(uint256 amount, uint256 price) public {
        // Limit values to reasonable ranges to avoid overflow and insufficient balance
        price = bound(price, 1, 99); // 100%
        amount = bound(amount, 1, 100 ether * 100 / price);

        vm.expectRevert("Sell is not allowed if you don't own shares");
        market.createOrder(BuySell.SELL, YesNo.NO, LimitMarket.MARKET, amount, price);
    }

    // Test zero amount revert
    function test_Market_CreateOrder_ZeroAmount() public {
        vm.expectRevert("Amount must be greater than zero");
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 0, 100);
    }

    // Test zero price revert
    function test_Market_CreateOrder_ZeroPrice() public {
        vm.expectRevert("Price must be greater than zero");
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 100, 0);
    }

    // Test both zero amount and price (should revert with amount error first)
    function test_Market_CreateOrder_ZeroAmountAndPrice() public {
        vm.expectRevert("Amount must be greater than zero");
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 0, 0);
    }

    function test_SellWithoutShares() public {
        vm.expectRevert("Sell is not allowed if you don't own shares");
        market.createOrder(BuySell.SELL, YesNo.YES, LimitMarket.LIMIT, 10, 10);
    }
}
