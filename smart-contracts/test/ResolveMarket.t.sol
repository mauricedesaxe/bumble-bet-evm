// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Market, OrderSide, MarketOutcome, OrderStatus, Order} from "../src/Market.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {MockERC20} from "../src/__mocks__/MockERC20.sol";

contract ResolveMarketTest is Test {
    IERC20 public token;
    Market public market;
    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);

    function setUp() public {
        token = IERC20(address(new MockERC20("Token", "TKN", 6)));
        market = new Market("TestMarket", address(token));

        // Set up balances
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);

        // Set up token balances
        token.mint(address(this), 100 ether);
        token.mint(alice, 100 ether);
        token.mint(bob, 100 ether);
        token.mint(charlie, 100 ether);

        // Set up token allowances
        token.approve(address(market), 100 ether);

        vm.startPrank(alice);
        token.approve(address(market), 100 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(market), 100 ether);
        vm.stopPrank();

        vm.startPrank(charlie);
        token.approve(address(market), 100 ether);
        vm.stopPrank();
    }

    /*────────────────────────
        ► RESOLVE MARKET TESTS
    ────────────────────────*/

    // Test successful market resolution with YES outcome
    function test_ResolveMarket_YES() public {
        assertEq(market.resolved(), false, "Market should not be resolved initially");

        market.resolveMarket(MarketOutcome.YES);

        assertEq(market.resolved(), true, "Market should be resolved");
        assertEq(uint256(market.outcome()), uint256(MarketOutcome.YES), "Outcome should be YES");
    }

    // Test successful market resolution with NO outcome
    function test_ResolveMarket_NO() public {
        assertEq(market.resolved(), false, "Market should not be resolved initially");

        market.resolveMarket(MarketOutcome.NO);

        assertEq(market.resolved(), true, "Market should be resolved");
        assertEq(uint256(market.outcome()), uint256(MarketOutcome.NO), "Outcome should be NO");
    }

    // Test that only owner can resolve market
    function test_ResolveMarket_OnlyOwner() public {
        vm.prank(alice);
        vm.expectRevert("Only the owner can resolve the market");
        market.resolveMarket(MarketOutcome.YES);

        // Verify market is still unresolved
        assertEq(market.resolved(), false, "Market should still be unresolved");
    }

    // Test that market cannot be resolved twice
    function test_ResolveMarket_AlreadyResolved() public {
        market.resolveMarket(MarketOutcome.YES);

        vm.expectRevert("Market is already resolved");
        market.resolveMarket(MarketOutcome.NO);

        // Verify outcome hasn't changed
        assertEq(uint256(market.outcome()), uint256(MarketOutcome.YES), "Outcome should still be YES");
    }

    // Fuzz test for different outcomes
    function testFuzz_ResolveMarket_Outcome(bool isYes) public {
        MarketOutcome expectedOutcome = isYes ? MarketOutcome.YES : MarketOutcome.NO;

        market.resolveMarket(expectedOutcome);

        assertEq(market.resolved(), true, "Market should be resolved");
        assertEq(uint256(market.outcome()), uint256(expectedOutcome), "Outcome should match input");
    }

    /*────────────────────────────────────
        ► CREATE ORDER AFTER RESOLUTION
    ────────────────────────────────────*/

    // Test that createOrder reverts after market is resolved
    function test_CreateOrder_AfterResolution_Reverts() public {
        market.resolveMarket(MarketOutcome.YES);

        vm.prank(alice);
        vm.expectRevert("Market is resolved");
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
    }

    // Test different order types all revert after resolution
    function test_CreateOrder_AllTypes_AfterResolution_Revert() public {
        // First create shares for alice and bob to test SELL orders
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        market.matchOrders(alice, bob, 1, 1);

        // Now resolve the market
        market.resolveMarket(MarketOutcome.NO);

        // Test BUY YES
        vm.prank(alice);
        vm.expectRevert("Market is resolved");
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);

        // Test BUY NO
        vm.prank(alice);
        vm.expectRevert("Market is resolved");
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);

        // Test SELL YES (alice has YES shares from the match)
        vm.prank(alice);
        vm.expectRevert("Market is resolved");
        market.createOrder(OrderSide.SELL, MarketOutcome.YES, 50, 50);

        // Test SELL NO (bob has NO shares from the match)
        vm.prank(bob);
        vm.expectRevert("Market is resolved");
        market.createOrder(OrderSide.SELL, MarketOutcome.NO, 50, 50);
    }

    // Fuzz test for createOrder after resolution
    function testFuzz_CreateOrder_AfterResolution(bool isYes, bool isBuy, bool orderYes, uint256 shares, uint256 price)
        public
    {
        shares = bound(shares, 1, 1000);
        price = bound(price, 1, 99);

        MarketOutcome resolutionOutcome = isYes ? MarketOutcome.YES : MarketOutcome.NO;
        market.resolveMarket(resolutionOutcome);

        OrderSide side = isBuy ? OrderSide.BUY : OrderSide.SELL;
        MarketOutcome orderOutcome = orderYes ? MarketOutcome.YES : MarketOutcome.NO;

        vm.prank(alice);
        vm.expectRevert("Market is resolved");
        market.createOrder(side, orderOutcome, shares, price);
    }

    /*────────────────────────────────────
        ► MATCH ORDERS AFTER RESOLUTION
    ────────────────────────────────────*/

    // Test that matchOrders reverts after market is resolved
    function test_MatchOrders_AfterResolution_Reverts() public {
        // Create orders before resolution
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);

        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);

        // Resolve market
        market.resolveMarket(MarketOutcome.YES);

        // Try to match orders after resolution
        vm.expectRevert("Market is resolved");
        market.matchOrders(alice, bob, 1, 1);
    }

    // Test different order combinations cannot be matched after resolution
    function test_MatchOrders_AllCombinations_AfterResolution() public {
        // Setup: Create various orders before resolution
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 200, 40);

        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 200, 60);

        // Match to create shares
        market.matchOrders(alice, bob, 1, 1);

        // Create more orders
        vm.prank(alice);
        market.createOrder(OrderSide.SELL, MarketOutcome.YES, 100, 50);

        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);

        // Create BUY-BUY orders for testing
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 30);

        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 70);

        // Resolve market
        market.resolveMarket(MarketOutcome.NO);

        // Try to match BUY-SELL after resolution
        vm.expectRevert("Market is resolved");
        market.matchOrders(bob, alice, 3, 2);

        // Try to match BUY-BUY after resolution
        vm.expectRevert("Market is resolved");
        market.matchOrders(alice, bob, 4, 4);
    }

    /*────────────────────────────────────
        ► CANCEL ORDER AFTER RESOLUTION
    ────────────────────────────────────*/

    // Test that users can still cancel orders after resolution
    function test_CancelOrder_AfterResolution_Succeeds() public {
        uint256 aliceBalanceBefore = token.balanceOf(alice);

        // Create order before resolution
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);

        // Resolve market
        market.resolveMarket(MarketOutcome.NO);

        // Cancel order after resolution should succeed
        vm.prank(alice);
        market.cancelOrder(1);

        // Verify order is cancelled and funds returned
        (,,,,, OrderStatus status) = market.orders(alice, 1);
        assertEq(uint256(status), uint256(OrderStatus.CANCELLED), "Order should be cancelled");

        uint256 aliceBalanceAfter = token.balanceOf(alice);
        assertEq(aliceBalanceAfter, aliceBalanceBefore, "Alice should get full refund");
    }

    // Test cancelling multiple orders after resolution
    function test_CancelMultipleOrders_AfterResolution() public {
        // Create multiple orders before resolution
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);

        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 200, 75);

        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 150, 60);

        // Resolve market
        market.resolveMarket(MarketOutcome.YES);

        // All users should be able to cancel their orders
        vm.prank(alice);
        market.cancelOrder(1);

        vm.prank(alice);
        market.cancelOrder(2);

        vm.prank(bob);
        market.cancelOrder(1);

        // Verify all orders are cancelled
        (,,,,, OrderStatus aliceStatus1) = market.orders(alice, 1);
        (,,,,, OrderStatus aliceStatus2) = market.orders(alice, 2);
        (,,,,, OrderStatus bobStatus) = market.orders(bob, 1);

        assertEq(uint256(aliceStatus1), uint256(OrderStatus.CANCELLED));
        assertEq(uint256(aliceStatus2), uint256(OrderStatus.CANCELLED));
        assertEq(uint256(bobStatus), uint256(OrderStatus.CANCELLED));
    }

    /*────────────────────────────────────
        ► COMPLEX SCENARIOS
    ────────────────────────────────────*/

    // Test partial fill before resolution, then resolution prevents further matching
    function test_PartialFill_ThenResolve() public {
        // Create orders with different sizes
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 150, 50);

        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);

        // Partial match
        market.matchOrders(alice, bob, 1, 1);

        // Verify alice has remaining order
        (, uint256 remaining,,,, OrderStatus status) = market.orders(alice, 1);
        assertEq(remaining, 50, "Alice should have 50 shares remaining");
        assertEq(uint256(status), uint256(OrderStatus.PENDING));

        // Resolve market
        market.resolveMarket(MarketOutcome.YES);

        // Create new order from charlie
        vm.prank(charlie);
        vm.expectRevert("Market is resolved");
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 50, 50);

        // Alice should still be able to cancel her remaining order
        vm.prank(alice);
        market.cancelOrder(1);
    }

    // Test that pending orders can be cancelled but not matched after resolution
    function test_PendingOrders_AfterResolution() public {
        // Create several orders
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 40);

        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);

        vm.prank(charlie);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 60);

        // Resolve market
        market.resolveMarket(MarketOutcome.NO);

        // Cannot match any orders
        vm.expectRevert("Market is resolved");
        market.matchOrders(alice, bob, 1, 1);

        vm.expectRevert("Market is resolved");
        market.matchOrders(charlie, bob, 1, 1);

        // But all orders can be cancelled
        vm.prank(alice);
        market.cancelOrder(1);

        vm.prank(bob);
        market.cancelOrder(1);

        vm.prank(charlie);
        market.cancelOrder(1);

        // Verify all cancelled
        (,,,,, OrderStatus aliceStatus) = market.orders(alice, 1);
        (,,,,, OrderStatus bobStatus) = market.orders(bob, 1);
        (,,,,, OrderStatus charlieStatus) = market.orders(charlie, 1);

        assertEq(uint256(aliceStatus), uint256(OrderStatus.CANCELLED));
        assertEq(uint256(bobStatus), uint256(OrderStatus.CANCELLED));
        assertEq(uint256(charlieStatus), uint256(OrderStatus.CANCELLED));
    }

    // Test state consistency after resolution
    function test_StateConsistency_AfterResolution() public {
        // Create and match some orders to establish share balances
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);

        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);

        market.matchOrders(alice, bob, 1, 1);

        // Create pending orders
        vm.prank(alice);
        market.createOrder(OrderSide.SELL, MarketOutcome.YES, 50, 60);

        vm.prank(bob);
        market.createOrder(OrderSide.SELL, MarketOutcome.NO, 50, 40);

        // Record state before resolution
        uint256 aliceYesShares = market.shares(alice, MarketOutcome.YES);
        uint256 bobNoShares = market.shares(bob, MarketOutcome.NO);
        uint256 marketBalance = token.balanceOf(address(market));

        // Resolve market
        market.resolveMarket(MarketOutcome.YES);

        // Verify share balances unchanged
        assertEq(market.shares(alice, MarketOutcome.YES), aliceYesShares, "Alice YES shares should be unchanged");
        assertEq(market.shares(bob, MarketOutcome.NO), bobNoShares, "Bob NO shares should be unchanged");

        // Verify market still holds escrowed funds from pending orders
        assertEq(token.balanceOf(address(market)), marketBalance, "Market balance should be unchanged");

        // Verify resolution state
        assertEq(market.resolved(), true);
        assertEq(uint256(market.outcome()), uint256(MarketOutcome.YES));
    }

    // Test resolution with maximum orders and shares
    function test_Resolution_WithMaxActivity() public {
        // Create many orders and matches
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(alice);
            market.createOrder(OrderSide.BUY, MarketOutcome.YES, 10, 45);

            vm.prank(bob);
            market.createOrder(OrderSide.BUY, MarketOutcome.NO, 10, 55);

            market.matchOrders(alice, bob, i + 1, i + 1);
        }

        // Create pending orders
        vm.prank(alice);
        market.createOrder(OrderSide.SELL, MarketOutcome.YES, 25, 50);

        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 30, 60);

        // Resolve market
        market.resolveMarket(MarketOutcome.NO);

        // Verify resolution
        assertEq(market.resolved(), true);
        assertEq(uint256(market.outcome()), uint256(MarketOutcome.NO));

        // Verify no new orders can be created
        vm.prank(charlie);
        vm.expectRevert("Market is resolved");
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 10, 50);

        // Verify no matches can occur
        vm.expectRevert("Market is resolved");
        market.matchOrders(bob, alice, 6, 6);
    }
}
