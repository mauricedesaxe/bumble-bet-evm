// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Market, BuySell, LimitMarket, YesNo, OrderStatus, Order} from "../src/Market.sol";

contract MatchOrdersTest is Test {
    Market public market;
    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);
    address carol = address(0xCC);

    function setUp() public {
        market = new Market("TestMarket");
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
        vm.deal(carol, 100 ether);
    }

    /*────────────────────────
        ► SUCCESSFUL MATCHES
    ────────────────────────*/

    function test_BuyBuy_YesNo_Match() public {
        // Alice creates a BUY order for YES
        vm.prank(alice);
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 100, 50);

        // Bob creates a BUY order for NO
        vm.prank(bob);
        market.createOrder(BuySell.BUY, YesNo.NO, LimitMarket.LIMIT, 100, 50);

        // Match orders
        market.matchOrders(alice, bob, 1, 1);

        // Verify orders are filled and shares are created
        (,,,,,, OrderStatus status1) = market.orders(alice, 1);
        (,,,,,, OrderStatus status2) = market.orders(bob, 1);
        assertEq(uint256(status1), uint256(OrderStatus.FILLED));
        assertEq(uint256(status2), uint256(OrderStatus.FILLED));
        assertEq(market.shares(alice, YesNo.YES), 100);
        assertEq(market.shares(bob, YesNo.NO), 100);
    }

    function test_BuySell_YesYes_Match() public {
        // Bob creates a BUY order for YES
        vm.startPrank(bob);
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 200, 40);
        vm.stopPrank();

        // Charlie creates a BUY order for NO
        vm.prank(charlie);
        market.createOrder(BuySell.BUY, YesNo.NO, LimitMarket.LIMIT, 200, 40);
        vm.stopPrank();

        // Owner matches Bob with Charlie (both BUY orders) which creates shares out of thin air
        market.matchOrders(bob, charlie, 1, 1);

        // Verify orders are filled and shares are created
        (,,,,,, OrderStatus status1) = market.orders(bob, 1);
        (,,,,,, OrderStatus status2) = market.orders(charlie, 1);
        assertEq(uint256(status1), uint256(OrderStatus.FILLED));
        assertEq(uint256(status2), uint256(OrderStatus.FILLED));
        assertEq(market.shares(bob, YesNo.YES), 200);
        assertEq(market.shares(charlie, YesNo.NO), 200);

        // Alice creates a BUY order for YES
        vm.prank(alice);
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 100, 50);
        vm.stopPrank();

        // Bob creates SELL order for half of his shares
        vm.prank(bob);
        market.createOrder(BuySell.SELL, YesNo.YES, LimitMarket.LIMIT, 100, 50);
        vm.stopPrank();

        // Owner matches Alice with Bob (Alice BUY, Bob SELL)
        market.matchOrders(alice, bob, 1, 2);

        // Verify orders are filled and shares are created
        (,,,,,, OrderStatus status3) = market.orders(alice, 1);
        (,,,,,, OrderStatus status4) = market.orders(bob, 2);
        assertEq(uint256(status3), uint256(OrderStatus.FILLED));
        assertEq(uint256(status4), uint256(OrderStatus.FILLED));
        assertEq(market.shares(alice, YesNo.YES), 100);
        assertEq(market.shares(bob, YesNo.YES), 100); // 200 initial - 100 sold
    }

    function test_BuySell_NoNo_Match() public {
        // Bob creates a BUY order for NO
        vm.startPrank(bob);
        market.createOrder(BuySell.BUY, YesNo.NO, LimitMarket.LIMIT, 200, 40);
        vm.stopPrank();

        // Charlie creates a BUY order for YES
        vm.prank(charlie);
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 200, 40);
        vm.stopPrank();

        // Owner matches Bob with Charlie (both BUY orders) which creates shares out of thin air
        market.matchOrders(bob, charlie, 1, 1);

        // Verify orders are filled and shares are created
        (,,,,,, OrderStatus status1) = market.orders(bob, 1);
        (,,,,,, OrderStatus status2) = market.orders(charlie, 1);
        assertEq(uint256(status1), uint256(OrderStatus.FILLED));
        assertEq(uint256(status2), uint256(OrderStatus.FILLED));
        assertEq(market.shares(bob, YesNo.NO), 200);
        assertEq(market.shares(charlie, YesNo.YES), 200);

        // Alice creates a BUY order for NO
        vm.prank(alice);
        market.createOrder(BuySell.BUY, YesNo.NO, LimitMarket.LIMIT, 100, 50);
        vm.stopPrank();

        // Bob creates SELL order for half of his shares
        vm.prank(bob);
        market.createOrder(BuySell.SELL, YesNo.NO, LimitMarket.LIMIT, 100, 50);
        vm.stopPrank();

        // Owner matches Alice with Bob (Alice BUY, Bob SELL)
        market.matchOrders(alice, bob, 1, 2);

        // Verify share balances and orders are filled
        (,,,,,, OrderStatus status3) = market.orders(alice, 1);
        (,,,,,, OrderStatus status4) = market.orders(bob, 2);
        assertEq(uint256(status3), uint256(OrderStatus.FILLED));
        assertEq(uint256(status4), uint256(OrderStatus.FILLED));
        assertEq(market.shares(alice, YesNo.NO), 100);
        assertEq(market.shares(bob, YesNo.NO), 100);
    }

    /*────────────────────────
        ► PARTIAL FILL TESTS
    ────────────────────────*/

    function test_PartialFill_BuySell_BuyerLarger() public {
        // Bob creates a BUY order for YES
        vm.prank(bob);
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 150, 40);
        vm.stopPrank();

        // Carol creates a BUY order for NO
        vm.prank(carol);
        market.createOrder(BuySell.BUY, YesNo.NO, LimitMarket.LIMIT, 150, 40);
        vm.stopPrank();

        // Owner matches Bob with Carol (Bob BUY, Carol BUY) which creates shares out of thin air
        market.matchOrders(bob, carol, 1, 1);

        // Alice creates a BUY order for 100 YES
        vm.prank(alice);
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 100, 50);
        vm.stopPrank();

        // Bob creates SELL order for 60 YES
        vm.prank(bob);
        market.createOrder(BuySell.SELL, YesNo.YES, LimitMarket.LIMIT, 60, 50);
        vm.stopPrank();

        // Owner matches Alice with Bob (Alice BUY, Bob SELL)
        market.matchOrders(alice, bob, 1, 2);

        // Buyer still needs 40 → order should stay PENDING w/ 40 left
        (, uint256 remaining0,,,,, OrderStatus status0) = market.orders(alice, 1);
        assertEq(remaining0, 40);
        assertEq(uint256(status0), uint256(OrderStatus.PENDING));

        // Seller completely filled → FILLED & no remaining
        (, uint256 remaining1,,,,, OrderStatus status1) = market.orders(bob, 2);
        assertEq(remaining1, 0);
        assertEq(uint256(status1), uint256(OrderStatus.FILLED));

        // Verify share balances
        assertEq(market.shares(alice, YesNo.YES), 60);
        assertEq(market.shares(bob, YesNo.YES), 90); // 150 – 60
    }

    function test_PartialFill_BuyBuy_YesNo_Symmetric() public {
        // Alice creates a BUY order for 80 YES
        vm.prank(alice);
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 80, 30);
        vm.stopPrank();

        // Bob creates a BUY order for 200 NO
        vm.prank(bob);
        market.createOrder(BuySell.BUY, YesNo.NO, LimitMarket.LIMIT, 200, 30);
        vm.stopPrank();

        // Owner matches Alice with Bob (Alice BUY, Bob BUY) which creates shares out of thin air
        market.matchOrders(alice, bob, 1, 1);

        // Alice completely filled
        (, uint256 remaining0,,,,, OrderStatus status0) = market.orders(alice, 1);
        assertEq(remaining0, 0);
        assertEq(uint256(status0), uint256(OrderStatus.FILLED));

        // Bob still has 120 NO to buy
        (, uint256 remaining1,,,,, OrderStatus status1) = market.orders(bob, 1);
        assertEq(remaining1, 120);
        assertEq(uint256(status1), uint256(OrderStatus.PENDING));

        // Verify share balances
        assertEq(market.shares(alice, YesNo.YES), 80);
        assertEq(market.shares(bob, YesNo.NO), 80);
    }

    /*────────────────────────
        ► FAILURE TESTS
    ────────────────────────*/

    function testFail_NonOwnerMatch() public {
        // Alice creates a BUY order for 100 YES
        vm.prank(alice);
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 100, 50);
        vm.stopPrank();

        // Bob creates a BUY order for 100 NO
        vm.prank(bob);
        market.createOrder(BuySell.BUY, YesNo.NO, LimitMarket.LIMIT, 100, 50);
        vm.stopPrank();

        // Non-owner tries to match
        vm.prank(carol);
        vm.expectRevert("Only the owner can match orders");
        market.matchOrders(alice, bob, 1, 1);
    }

    function testFail_SameUserMatch() public {
        // Alice creates a BUY order for 100 YES
        vm.prank(alice);
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 100, 50);
        vm.stopPrank();

        // Alice creates a BUY order for 100 NO
        vm.prank(alice);
        market.createOrder(BuySell.BUY, YesNo.NO, LimitMarket.LIMIT, 100, 50);
        vm.stopPrank();

        // Should fail because same user
        vm.expectRevert("Cannot match orders for the same user");
        market.matchOrders(alice, alice, 1, 2);
    }

    function testFail_NonExistentOrder() public {
        // Alice creates a BUY order for 100 YES
        vm.prank(alice);
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 100, 50);
        vm.stopPrank();

        // Non-existent order
        vm.expectRevert("Order does not exist");
        market.matchOrders(alice, bob, 1, 999);
    }

    function testFail_CancelledOrder() public {
        // Alice creates a BUY order for 100 YES
        vm.prank(alice);
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 100, 50);
        vm.stopPrank();

        // Bob creates a BUY order for 100 NO
        vm.prank(bob);
        market.createOrder(BuySell.BUY, YesNo.NO, LimitMarket.LIMIT, 100, 50);
        vm.stopPrank();

        // Cancel Bob's order
        vm.prank(bob);
        market.cancelOrder(1);
        vm.stopPrank();

        // Try to match with cancelled order
        vm.expectRevert("Cannot match non-pending orders");
        market.matchOrders(alice, bob, 1, 1);
    }

    function testFail_IncompatibleOrders_YesNo() public {
        // Alice creates a BUY order for 100 YES
        vm.prank(alice);
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 100, 50);
        vm.stopPrank();

        // Bob creates a SELL order for 100 NO
        vm.prank(bob);
        market.createOrder(BuySell.SELL, YesNo.NO, LimitMarket.LIMIT, 100, 50);
        vm.stopPrank();

        // Should fail - YES-NO in BUY-SELL
        vm.expectRevert("Need to be yes-yes or no-no to match buy-sell orders");
        market.matchOrders(alice, bob, 1, 1);
    }

    function testFail_MatchAlreadyFilled() public {
        vm.prank(alice);
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 10, 10);

        vm.prank(bob);
        market.createOrder(BuySell.BUY, YesNo.NO, LimitMarket.LIMIT, 10, 10);

        market.matchOrders(alice, bob, 1, 1);

        // orders are FILLED, second match should revert
        vm.expectRevert("Cannot match non-pending orders");
        market.matchOrders(alice, bob, 1, 1);
    }

    /*────────────────────────
        ► INVARIANT TEST
       (YES total == NO total)
    ────────────────────────*/

    uint256 private totalYes;
    uint256 private totalNo;

    /// @notice Updates the total YES and NO shares
    function _updateTotals() private {
        totalYes = market.shares(alice, YesNo.YES) + market.shares(bob, YesNo.YES);
        totalNo = market.shares(alice, YesNo.NO) + market.shares(bob, YesNo.NO);
    }

    function testFuzz_Invariant_YesEqualsNo_AfterBuyBuyMatches(uint256 amount1, uint256 amount2, uint256 price)
        public
    {
        // Skip zero values
        vm.assume(amount1 > 0);
        vm.assume(amount2 > 0);
        vm.assume(price > 0);

        _updateTotals();
        assertEq(totalYes, totalNo, "YES / NO totals must be equal before matching (1)");

        // Alice creates a BUY order for YES
        vm.prank(alice);
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, amount1, price);
        vm.stopPrank();

        // Bob creates a BUY order for NO
        vm.prank(bob);
        market.createOrder(BuySell.BUY, YesNo.NO, LimitMarket.LIMIT, amount2, price);
        vm.stopPrank();

        // Owner matches Alice with Bob (Alice BUY, Bob BUY)
        market.matchOrders(alice, bob, 1, 1);

        // Verify that the total YES and NO shares are equal
        _updateTotals();
        assertEq(totalYes, totalNo, "YES / NO totals must be equal after matching (2)");
    }
}
