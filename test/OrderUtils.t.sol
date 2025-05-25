// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {OrderUtils} from "../src/OrderUtils.sol";
import {Order, OrderSide, MarketOutcome, OrderStatus} from "../src/Market.sol";

contract OrderUtilsTest is Test {
    using OrderUtils for Order;

    // Test orders - using mapping to store in contract storage
    mapping(uint256 => Order) public testOrders;

    function setUp() public {
        // Create test orders with different combinations
        testOrders[0] = Order({
            user: address(0x1),
            shares: 100,
            price: 50,
            side: OrderSide.BUY,
            yesNo: MarketOutcome.YES,
            status: OrderStatus.PENDING
        });

        testOrders[1] = Order({
            user: address(0x2),
            shares: 100,
            price: 50,
            side: OrderSide.BUY,
            yesNo: MarketOutcome.NO,
            status: OrderStatus.PENDING
        });

        testOrders[2] = Order({
            user: address(0x3),
            shares: 100,
            price: 50,
            side: OrderSide.SELL,
            yesNo: MarketOutcome.YES,
            status: OrderStatus.PENDING
        });

        testOrders[3] = Order({
            user: address(0x4),
            shares: 100,
            price: 50,
            side: OrderSide.SELL,
            yesNo: MarketOutcome.NO,
            status: OrderStatus.PENDING
        });
    }

    // Test isBuySell function
    function test_isBuySell_BuyAndSell() public view {
        assertTrue(OrderUtils.isBuySell(testOrders[0], testOrders[2]));
    }

    function test_isBuySell_BuyAndBuy() public view {
        assertFalse(OrderUtils.isBuySell(testOrders[0], testOrders[1]));
    }

    function test_isBuySell_SellAndBuy() public view {
        assertFalse(OrderUtils.isBuySell(testOrders[2], testOrders[0]));
    }

    function test_isBuySell_SellAndSell() public view {
        assertFalse(OrderUtils.isBuySell(testOrders[2], testOrders[3]));
    }

    // Test isBuyBuy function
    function test_isBuyBuy_BuyAndBuy() public view {
        assertTrue(OrderUtils.isBuyBuy(testOrders[0], testOrders[1]));
    }

    function test_isBuyBuy_BuyAndSell() public view {
        assertFalse(OrderUtils.isBuyBuy(testOrders[0], testOrders[2]));
    }

    function test_isBuyBuy_SellAndSell() public view {
        assertFalse(OrderUtils.isBuyBuy(testOrders[2], testOrders[3]));
    }

    // Test isYesYes function
    function test_isYesYes_YesAndYes() public view {
        assertTrue(OrderUtils.isYesYes(testOrders[0], testOrders[2]));
    }

    function test_isYesYes_YesAndNo() public view {
        assertFalse(OrderUtils.isYesYes(testOrders[0], testOrders[1]));
    }

    function test_isYesYes_NoAndNo() public view {
        assertFalse(OrderUtils.isYesYes(testOrders[1], testOrders[3]));
    }

    // Test isNoNo function
    function test_isNoNo_NoAndNo() public view {
        assertTrue(OrderUtils.isNoNo(testOrders[1], testOrders[3]));
    }

    function test_isNoNo_NoAndYes() public view {
        assertFalse(OrderUtils.isNoNo(testOrders[1], testOrders[0]));
    }

    function test_isNoNo_YesAndYes() public view {
        assertFalse(OrderUtils.isNoNo(testOrders[0], testOrders[2]));
    }

    // Test isYesNo function
    function test_isYesNo_YesAndNo() public view {
        assertTrue(OrderUtils.isYesNo(testOrders[0], testOrders[1]));
    }

    function test_isYesNo_NoAndYes() public view {
        assertFalse(OrderUtils.isYesNo(testOrders[1], testOrders[0]));
    }

    function test_isYesNo_YesAndYes() public view {
        assertFalse(OrderUtils.isYesNo(testOrders[0], testOrders[2]));
    }

    function test_isYesNo_NoAndNo() public view {
        assertFalse(OrderUtils.isYesNo(testOrders[1], testOrders[3]));
    }

    function test_functionsWorkWithDifferentOrderStatuses() public {
        // Create filled order
        testOrders[4] = Order({
            user: address(0x5),
            shares: 0,
            price: 50,
            side: OrderSide.BUY,
            yesNo: MarketOutcome.YES,
            status: OrderStatus.FILLED
        });

        // Functions should still work based on side/outcome regardless of status
        assertTrue(OrderUtils.isBuySell(testOrders[4], testOrders[2]));
        assertTrue(OrderUtils.isYesYes(testOrders[4], testOrders[2]));
    }

    function test_functionsWorkWithCancelledOrders() public {
        // Create cancelled order
        testOrders[5] = Order({
            user: address(0x6),
            shares: 100,
            price: 50,
            side: OrderSide.SELL,
            yesNo: MarketOutcome.NO,
            status: OrderStatus.CANCELLED
        });

        // Functions should still evaluate based on side/outcome
        assertTrue(OrderUtils.isBuySell(testOrders[1], testOrders[5]));
        assertTrue(OrderUtils.isNoNo(testOrders[1], testOrders[5]));
    }
}
