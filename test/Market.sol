// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Market, BuySell, LimitMarket, YesNo, OrderStatus, Order} from "../src/Market.sol";

contract MarketTest is Test {
    Market public market;

    function setUp() public {
        market = new Market("Market");
    }

    function test_Market() public view {
        assertEq(market.name(), "Market");
    }

    function test_Market_setName() public {
        market.setName("New Market");
        assertEq(market.name(), "New Market");
    }

    function test_Market_setName_Revert() public {
        vm.prank(address(1));
        vm.expectRevert("Only the owner can set the name");
        market.setName("New Market");
    }

    // BUY-YES-LIMIT
    function test_Market_createOrder_BuyYesLimit() public {
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 100, 100);
        assertEq(market.orderCount(address(this)), 1);

        (
            address user,
            uint256 amount,
            uint256 price,
            BuySell side,
            YesNo yesNo,
            LimitMarket limitMarket,
            OrderStatus status
        ) = market.orders(address(this), 1);

        assertEq(user, address(this));
        assertEq(uint256(side), uint256(BuySell.BUY));
        assertEq(uint256(yesNo), uint256(YesNo.YES));
        assertEq(uint256(limitMarket), uint256(LimitMarket.LIMIT));
        assertEq(amount, 100);
        assertEq(price, 100);
        assertEq(uint256(status), uint256(OrderStatus.PENDING));
    }

    // BUY-YES-MARKET
    function test_Market_createOrder_BuyYesMarket() public {
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.MARKET, 100, 100);
        assertEq(market.orderCount(address(this)), 1);

        (
            address user,
            uint256 amount,
            uint256 price,
            BuySell side,
            YesNo yesNo,
            LimitMarket limitMarket,
            OrderStatus status
        ) = market.orders(address(this), 1);

        assertEq(user, address(this));
        assertEq(uint256(side), uint256(BuySell.BUY));
        assertEq(uint256(yesNo), uint256(YesNo.YES));
        assertEq(uint256(limitMarket), uint256(LimitMarket.MARKET));
        assertEq(amount, 100);
        assertEq(price, 100);
        assertEq(uint256(status), uint256(OrderStatus.PENDING));
    }

    // BUY-NO-LIMIT
    function test_Market_createOrder_BuyNoLimit() public {
        market.createOrder(BuySell.BUY, YesNo.NO, LimitMarket.LIMIT, 100, 100);
        assertEq(market.orderCount(address(this)), 1);

        (
            address user,
            uint256 amount,
            uint256 price,
            BuySell side,
            YesNo yesNo,
            LimitMarket limitMarket,
            OrderStatus status
        ) = market.orders(address(this), 1);

        assertEq(user, address(this));
        assertEq(uint256(side), uint256(BuySell.BUY));
        assertEq(uint256(yesNo), uint256(YesNo.NO));
        assertEq(uint256(limitMarket), uint256(LimitMarket.LIMIT));
        assertEq(amount, 100);
        assertEq(price, 100);
        assertEq(uint256(status), uint256(OrderStatus.PENDING));
    }

    // BUY-NO-MARKET
    function test_Market_createOrder_BuyNoMarket() public {
        market.createOrder(BuySell.BUY, YesNo.NO, LimitMarket.MARKET, 100, 100);
        assertEq(market.orderCount(address(this)), 1);
    }

    // SELL-YES-LIMIT (should revert)
    function test_Market_createOrder_SellYesLimit() public {
        vm.expectRevert("Sell is not allowed if you don't own shares");
        market.createOrder(BuySell.SELL, YesNo.YES, LimitMarket.LIMIT, 100, 100);
    }

    // SELL-YES-MARKET (should revert)
    function test_Market_createOrder_SellYesMarket() public {
        vm.expectRevert("Sell is not allowed if you don't own shares");
        market.createOrder(BuySell.SELL, YesNo.YES, LimitMarket.MARKET, 100, 100);
    }

    // SELL-NO-LIMIT (should revert)
    function test_Market_createOrder_SellNoLimit() public {
        vm.expectRevert("Sell is not allowed if you don't own shares");
        market.createOrder(BuySell.SELL, YesNo.NO, LimitMarket.LIMIT, 100, 100);
    }

    // SELL-NO-MARKET (should revert)
    function test_Market_createOrder_SellNoMarket() public {
        vm.expectRevert("Sell is not allowed if you don't own shares");
        market.createOrder(BuySell.SELL, YesNo.NO, LimitMarket.MARKET, 100, 100);
    }
}
