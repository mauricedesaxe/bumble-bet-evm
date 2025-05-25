// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Market, OrderSide, MarketOutcome, OrderStatus, Order} from "../src/Market.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {MockERC20} from "../src/__mocks__/MockERC20.sol";

contract MatchOrdersTest is Test {
    IERC20 public token;
    Market public market;
    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);
    address carol = address(0xCC);

    function setUp() public {
        token = IERC20(address(new MockERC20("Token", "TKN", 6)));
        market = new Market("TestMarket", address(token));

        // Set up balances
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
        vm.deal(carol, 100 ether);

        // Set up token balances
        token.mint(address(this), 100 ether);
        token.mint(alice, 100 ether);
        token.mint(bob, 100 ether);
        token.mint(charlie, 100 ether);
        token.mint(carol, 100 ether);

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

        vm.startPrank(carol);
        token.approve(address(market), 100 ether);
        vm.stopPrank();
    }

    /*────────────────────────
        ► SUCCESSFUL MATCHES
    ────────────────────────*/

    function test_BuyBuy_YesNo_Match() public {
        // Alice creates a BUY order for YES
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);

        // Bob creates a BUY order for NO
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);

        // Match orders
        market.matchOrders(alice, bob, 1, 1);

        // Verify orders are filled and shares are created
        (,,,,, OrderStatus status1) = market.orders(alice, 1);
        (,,,,, OrderStatus status2) = market.orders(bob, 1);
        assertEq(uint256(status1), uint256(OrderStatus.FILLED));
        assertEq(uint256(status2), uint256(OrderStatus.FILLED));
        assertEq(market.shares(alice, MarketOutcome.YES), 100);
        assertEq(market.shares(bob, MarketOutcome.NO), 100);
    }

    function test_BuySell_YesYes_Match() public {
        // Bob creates a BUY order for YES
        vm.startPrank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 200, 60);
        vm.stopPrank();

        // Charlie creates a BUY order for NO
        vm.prank(charlie);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 200, 40);
        vm.stopPrank();

        // Owner matches Bob with Charlie (both BUY orders) which creates shares out of thin air
        market.matchOrders(bob, charlie, 1, 1);

        // Verify orders are filled and shares are created
        (,,,,, OrderStatus status1) = market.orders(bob, 1);
        (,,,,, OrderStatus status2) = market.orders(charlie, 1);
        assertEq(uint256(status1), uint256(OrderStatus.FILLED));
        assertEq(uint256(status2), uint256(OrderStatus.FILLED));
        assertEq(market.shares(bob, MarketOutcome.YES), 200);
        assertEq(market.shares(charlie, MarketOutcome.NO), 200);

        // Alice creates a BUY order for YES
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.stopPrank();

        // Bob creates SELL order for half of his shares
        vm.prank(bob);
        market.createOrder(OrderSide.SELL, MarketOutcome.YES, 100, 50);
        vm.stopPrank();

        // Owner matches Alice with Bob (Alice BUY, Bob SELL)
        market.matchOrders(alice, bob, 1, 2);

        // Verify orders are filled and shares are created
        (,,,,, OrderStatus status3) = market.orders(alice, 1);
        (,,,,, OrderStatus status4) = market.orders(bob, 2);
        assertEq(uint256(status3), uint256(OrderStatus.FILLED));
        assertEq(uint256(status4), uint256(OrderStatus.FILLED));
        assertEq(market.shares(alice, MarketOutcome.YES), 100);
        assertEq(market.shares(bob, MarketOutcome.YES), 100); // 200 initial - 100 sold
    }

    function test_BuySell_NoNo_Match() public {
        // Bob creates a BUY order for NO
        vm.startPrank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 200, 50);
        vm.stopPrank();

        // Charlie creates a BUY order for YES
        vm.prank(charlie);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 200, 50);
        vm.stopPrank();

        // Owner matches Bob with Charlie (both BUY orders) which creates shares out of thin air
        // Have Charlie the first order to have a Yes-No order instead of a No-Yes
        market.matchOrders(charlie, bob, 1, 1);

        // Verify orders are filled and shares are created
        (,,,,, OrderStatus status1) = market.orders(bob, 1);
        (,,,,, OrderStatus status2) = market.orders(charlie, 1);
        assertEq(uint256(status1), uint256(OrderStatus.FILLED));
        assertEq(uint256(status2), uint256(OrderStatus.FILLED));
        assertEq(market.shares(bob, MarketOutcome.NO), 200);
        assertEq(market.shares(charlie, MarketOutcome.YES), 200);

        // Alice creates a BUY order for NO
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        vm.stopPrank();

        // Bob creates SELL order for half of his shares
        vm.prank(bob);
        market.createOrder(OrderSide.SELL, MarketOutcome.NO, 100, 50);
        vm.stopPrank();

        // Owner matches Alice with Bob (Alice BUY, Bob SELL)
        market.matchOrders(alice, bob, 1, 2);

        // Verify share balances and orders are filled
        (,,,,, OrderStatus status3) = market.orders(alice, 1);
        (,,,,, OrderStatus status4) = market.orders(bob, 2);
        assertEq(uint256(status3), uint256(OrderStatus.FILLED));
        assertEq(uint256(status4), uint256(OrderStatus.FILLED));
        assertEq(market.shares(alice, MarketOutcome.NO), 100);
        assertEq(market.shares(bob, MarketOutcome.NO), 100);
    }

    /*────────────────────────
        ► PARTIAL FILL TESTS
    ────────────────────────*/

    function test_PartialFill_BuySell_BuyerLarger() public {
        // Bob creates a BUY order for YES
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 150, 40);
        vm.stopPrank();

        // Carol creates a BUY order for NO
        vm.prank(carol);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 150, 60);
        vm.stopPrank();

        // Owner matches Bob with Carol (Bob BUY, Carol BUY) which creates shares out of thin air
        market.matchOrders(bob, carol, 1, 1);

        // Alice creates a BUY order for 100 YES
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.stopPrank();

        // Bob creates SELL order for 60 YES
        vm.prank(bob);
        market.createOrder(OrderSide.SELL, MarketOutcome.YES, 60, 50);
        vm.stopPrank();

        // Owner matches Alice with Bob (Alice BUY, Bob SELL)
        market.matchOrders(alice, bob, 1, 2);

        // Buyer still needs 40 → order should stay PENDING w/ 40 left
        (, uint256 remaining0,,,, OrderStatus status0) = market.orders(alice, 1);
        assertEq(remaining0, 40, "Alice should have 40 YES shares remaining in her order");
        assertEq(uint256(status0), uint256(OrderStatus.PENDING), "Alice's order should be PENDING");

        // Seller completely filled → FILLED & no remaining
        (, uint256 remaining1,,,, OrderStatus status1) = market.orders(bob, 2);
        assertEq(remaining1, 0, "Bob should have 0 YES shares remaining in his order");
        assertEq(uint256(status1), uint256(OrderStatus.FILLED), "Bob's order should be FILLED");

        // Verify share balances
        assertEq(market.shares(alice, MarketOutcome.YES), 60, "Alice should have 60 YES shares");
        assertEq(market.shares(bob, MarketOutcome.YES), 90, "Bob should have 90 YES shares"); // 150 – 60
    }

    function test_PartialFill_BuyBuy_YesNo_Symmetric() public {
        // Alice creates a BUY order for 80 YES
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 80, 30);
        vm.stopPrank();

        // Bob creates a BUY order for 200 NO
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 200, 70);
        vm.stopPrank();

        // Owner matches Alice with Bob (Alice BUY, Bob BUY) which creates shares out of thin air
        market.matchOrders(alice, bob, 1, 1);

        // Alice completely filled
        (, uint256 remaining0,,,, OrderStatus status0) = market.orders(alice, 1);
        assertEq(remaining0, 0, "Alice should have 0 remaining shares in her order");
        assertEq(uint256(status0), uint256(OrderStatus.FILLED), "Alice's order should be FILLED");

        // Bob still has 120 NO to buy
        (, uint256 remaining1,,,, OrderStatus status1) = market.orders(bob, 1);
        assertEq(remaining1, 120, "Bob should have 120 NO shares remaining in his order");
        assertEq(uint256(status1), uint256(OrderStatus.PENDING), "Bob's order should be PENDING");

        // Verify share balances
        assertEq(market.shares(alice, MarketOutcome.YES), 80, "Alice should have 80 YES shares");
        assertEq(market.shares(bob, MarketOutcome.NO), 80, "Bob should have 80 NO shares");
    }

    /*────────────────────────
        ► FAILURE TESTS
    ────────────────────────*/

    function test_NonOwnerMatch() public {
        // Alice creates a BUY order for 100 YES
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.stopPrank();

        // Bob creates a BUY order for 100 NO
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        vm.stopPrank();

        // Non-owner tries to match
        vm.prank(carol);
        vm.expectRevert("Only the owner can match orders");
        market.matchOrders(alice, bob, 1, 1);
    }

    function test_SameUserMatch() public {
        // Alice creates a BUY order for 100 YES
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.stopPrank();

        // Alice creates a BUY order for 100 NO
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        vm.stopPrank();

        // Should fail because same user
        vm.expectRevert("Cannot match orders for the same user");
        market.matchOrders(alice, alice, 1, 2);
    }

    function test_NonExistentOrder() public {
        // Alice creates a BUY order for 100 YES
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.stopPrank();

        // Non-existent order
        vm.expectRevert("Order does not exist");
        market.matchOrders(alice, bob, 1, 999);
    }

    function test_CancelledOrder() public {
        // Alice creates a BUY order for 100 YES
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.stopPrank();

        // Bob creates a BUY order for 100 NO
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        vm.stopPrank();

        // Cancel Bob's order
        vm.prank(bob);
        market.cancelOrder(1);
        vm.stopPrank();

        // Try to match with cancelled order
        vm.expectRevert("Cannot match non-pending orders");
        market.matchOrders(alice, bob, 1, 1);
    }

    function test_IncompatibleOrders_YesNo() public {
        // Charlie creates a BUY order for Yes
        vm.prank(charlie);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.stopPrank();

        // Bob creates a BUY order for No
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        vm.stopPrank();

        // Owner matches Bob with Charlie (Bob BUY, Charlie BUY) which creates shares out of thin air
        market.matchOrders(charlie, bob, 1, 1);

        // Verify shares are created
        assertEq(market.shares(charlie, MarketOutcome.YES), 100);
        assertEq(market.shares(bob, MarketOutcome.NO), 100);

        // Alice creates a BUY order for 100 YES
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.stopPrank();

        // Bob creates a SELL order for 100 NO
        vm.prank(bob);
        market.createOrder(OrderSide.SELL, MarketOutcome.NO, 100, 50);
        vm.stopPrank();

        // Should fail - YES-NO in BUY-SELL
        vm.expectRevert("Need to be yes-yes or no-no to match buy-sell orders");
        market.matchOrders(alice, bob, 1, 2);
    }

    function test_MatchAlreadyFilled() public {
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 10, 10);
        vm.stopPrank();

        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 10, 90);
        vm.stopPrank();

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
        totalYes = market.shares(alice, MarketOutcome.YES) + market.shares(bob, MarketOutcome.YES);
        totalNo = market.shares(alice, MarketOutcome.NO) + market.shares(bob, MarketOutcome.NO);
    }

    function testFuzz_Invariant_YesEqualsNo_AfterBuyBuyMatches(uint256 amount1, uint256 amount2, uint256 yesPrice)
        public
    {
        // Limit values to reasonable ranges to avoid overflow and insufficient balance
        yesPrice = bound(yesPrice, 1, 99);
        uint256 noPrice = 100 - yesPrice;
        // Calculate max amount based on available balance and price
        // We have 100 * 10^18 tokens, need to ensure amount * price * 10^6 / 100 <= balance
        // So amount <= balance * 100 / (price * 10^6)
        uint256 maxAmount1 = (token.balanceOf(address(this)) * 100) / (yesPrice * 10 ** token.decimals());
        uint256 maxAmount2 = (token.balanceOf(address(this)) * 100) / (noPrice * 10 ** token.decimals());
        amount1 = bound(amount1, 1, maxAmount1);
        amount2 = bound(amount2, 1, maxAmount2);

        // Skip zero values
        vm.assume(amount1 > 0);
        vm.assume(amount2 > 0);

        _updateTotals();
        assertEq(totalYes, totalNo, "YES / NO totals must be equal before matching (1)");

        // Alice creates a BUY order for YES
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, amount1, yesPrice);
        vm.stopPrank();

        // Bob creates a BUY order for NO
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, amount2, noPrice);
        vm.stopPrank();

        // Owner matches Alice with Bob (Alice BUY, Bob BUY)
        market.matchOrders(alice, bob, 1, 1);

        // Verify that the total YES and NO shares are equal
        _updateTotals();
        assertEq(totalYes, totalNo, "YES / NO totals must be equal after matching (2)");
    }

    /*────────────────────────
        ► PRICE TESTS
    ────────────────────────*/

    function test_BuySell_PriceMismatch_Reverts() public {
        // Bob creates a BUY order for YES at price 50
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.stopPrank();

        // Charlie creates a BUY order for NO at price 50
        vm.prank(charlie);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        vm.stopPrank();

        // Owner matches Bob with Charlie (Bob BUY, Charlie BUY) which creates shares out of thin air
        market.matchOrders(bob, charlie, 1, 1);

        // Alice creates a BUY order for YES at price 40
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 40);
        vm.stopPrank();

        // Bob creates a SELL order for YES at price 50
        vm.prank(bob);
        market.createOrder(OrderSide.SELL, MarketOutcome.YES, 100, 50);
        vm.stopPrank();

        // Owner tries to match - should revert with "BUY price below SELL price"
        vm.expectRevert("BUY price below SELL price");
        market.matchOrders(alice, bob, 1, 2);
    }

    function test_BuySell_BuyerHigherPrice_Succeeds() public {
        // Bob creates a BUY order for YES at price 50
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.stopPrank();

        // Charlie creates a BUY order for NO at price 50
        vm.prank(charlie);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        vm.stopPrank();

        // Owner matches Bob with Charlie (Bob BUY, Charlie BUY) which creates shares out of thin air
        market.matchOrders(bob, charlie, 1, 1);

        // Alice creates a BUY order for YES at higher price (70)
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 70);
        vm.stopPrank();

        // Bob creates a SELL order for YES at lower price (50)
        vm.prank(bob);
        market.createOrder(OrderSide.SELL, MarketOutcome.YES, 100, 50);
        vm.stopPrank();

        // Owner matches - should succeed even though prices differ
        market.matchOrders(alice, bob, 1, 2);

        // Verify orders are filled and shares transferred
        (,,,,, OrderStatus status1) = market.orders(alice, 1);
        (,,,,, OrderStatus status2) = market.orders(bob, 2);
        assertEq(uint256(status1), uint256(OrderStatus.FILLED));
        assertEq(uint256(status2), uint256(OrderStatus.FILLED));
        assertEq(market.shares(alice, MarketOutcome.YES), 100);
        assertEq(market.shares(bob, MarketOutcome.YES), 0); // Started with 100, sold 100
    }

    function test_BuyBuy_PriceSum_Invalid_Reverts() public {
        // Alice creates a BUY order for YES at price 60
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 60);
        vm.stopPrank();

        // Bob creates a BUY order for NO at price 60 (sum = 120)
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 60);
        vm.stopPrank();

        // Owner tries to match - should revert with "YES+NO prices must sum to 100"
        vm.expectRevert("YES+NO prices must sum to 100");
        market.matchOrders(alice, bob, 1, 1);
    }

    function test_BuyBuy_ExactPriceSum_Succeeds() public {
        // Alice creates a BUY order for YES at price 25
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 25);
        vm.stopPrank();

        // Bob creates a BUY order for NO at price 75 (sum = 100 exactly)
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 75);
        vm.stopPrank();

        // Owner tries to match - should succeed with exactly PRICE_UNIT sum
        market.matchOrders(alice, bob, 1, 1);

        // Verify orders are filled and shares created
        (,,,,, OrderStatus status1) = market.orders(alice, 1);
        (,,,,, OrderStatus status2) = market.orders(bob, 1);
        assertEq(uint256(status1), uint256(OrderStatus.FILLED));
        assertEq(uint256(status2), uint256(OrderStatus.FILLED));
        assertEq(market.shares(alice, MarketOutcome.YES), 100);
        assertEq(market.shares(bob, MarketOutcome.NO), 100);
    }

    function test_BuyBuy_PriceSum_TooLow_Reverts() public {
        // Alice creates a BUY order for YES at price 30
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 30);
        vm.stopPrank();

        // Bob creates a BUY order for NO at price 60 (sum = 90 < 100)
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 60);
        vm.stopPrank();

        // Owner tries to match - should revert with "YES+NO prices must sum to 100"
        vm.expectRevert("YES+NO prices must sum to 100");
        market.matchOrders(alice, bob, 1, 1);
    }

    function test_PartialFill_WithPriceDifference() public {
        // Bob creates a BUY order for YES
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 150, 50);
        vm.stopPrank();

        // Charlie creates a BUY order for NO
        vm.prank(charlie);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 150, 50);
        vm.stopPrank();

        // Owner matches Bob with Charlie (Bob BUY, Charlie BUY) which creates shares out of thin air
        market.matchOrders(bob, charlie, 1, 1);

        // Alice creates a BUY order for 100 YES at price 80 (high price)
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 80);
        vm.stopPrank();

        // Bob creates SELL order for 60 YES at price 50 (lower price)
        vm.prank(bob);
        market.createOrder(OrderSide.SELL, MarketOutcome.YES, 60, 50);
        vm.stopPrank();

        // Owner matches Alice with Bob (Alice BUY, Bob SELL)
        market.matchOrders(alice, bob, 1, 2);

        // Alice's order is partially filled - should remain PENDING with 40 remaining
        (, uint256 remaining0,,,, OrderStatus status0) = market.orders(alice, 1);
        assertEq(remaining0, 40);
        assertEq(uint256(status0), uint256(OrderStatus.PENDING));

        // Bob's order is fully filled
        (,,,,, OrderStatus status1) = market.orders(bob, 2);
        assertEq(uint256(status1), uint256(OrderStatus.FILLED));

        // Verify share balances
        assertEq(market.shares(alice, MarketOutcome.YES), 60);
        assertEq(market.shares(bob, MarketOutcome.YES), 90); // 150 - 60
    }

    function test_MinMaxPrice_EdgeCases() public {
        // Test with price 1 (minimum reasonable price)
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 1);
        vm.stopPrank();

        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 99);
        vm.stopPrank();

        // Should succeed
        market.matchOrders(alice, bob, 1, 1);

        // Test with price 99 (maximum reasonable price)
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 99);
        vm.stopPrank();

        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 1);
        vm.stopPrank();

        // Should succeed
        market.matchOrders(alice, bob, 2, 2);

        // Verify shares
        assertEq(market.shares(alice, MarketOutcome.YES), 200);
        assertEq(market.shares(bob, MarketOutcome.NO), 200);
    }

    function test_BuySell_ExactPriceMatch_Succeeds() public {
        // Bob creates a BUY order for YES at price 50
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.stopPrank();

        // Charlie creates a BUY order for NO at price 50
        vm.prank(charlie);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        vm.stopPrank();

        // Owner matches Bob with Charlie (Bob BUY, Charlie BUY) which creates shares out of thin air
        market.matchOrders(bob, charlie, 1, 1);

        // Alice creates a BUY order for YES at exact same price as Bob's sell
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.stopPrank();

        // Bob creates a SELL order for YES at exactly the same price
        vm.prank(bob);
        market.createOrder(OrderSide.SELL, MarketOutcome.YES, 100, 50);
        vm.stopPrank();

        // Owner matches - should succeed with equal prices
        market.matchOrders(alice, bob, 1, 2);

        // Verify orders are filled and shares transferred
        (,,,,, OrderStatus status1) = market.orders(alice, 1);
        (,,,,, OrderStatus status2) = market.orders(bob, 2);
        assertEq(uint256(status1), uint256(OrderStatus.FILLED));
        assertEq(uint256(status2), uint256(OrderStatus.FILLED));
        assertEq(market.shares(alice, MarketOutcome.YES), 100);
        assertEq(market.shares(bob, MarketOutcome.YES), 0);
    }

    function test_BuyBuy_UnequalAmounts_SmallerSideCaps() public {
        // Alice creates a BUY order for 100 YES at price 40
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 40);
        vm.stopPrank();

        // Bob creates a BUY order for 50 NO at price 60
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 50, 60);
        vm.stopPrank();

        // Owner matches Alice with Bob (Alice BUY, Bob BUY) which creates shares out of thin air
        market.matchOrders(alice, bob, 1, 1);

        // Bob's order (smaller) should be FILLED
        (,,,,, OrderStatus status2) = market.orders(bob, 1);
        assertEq(uint256(status2), uint256(OrderStatus.FILLED));

        // Alice's order should be PENDING with 50 remaining
        (, uint256 remaining1,,,, OrderStatus status1) = market.orders(alice, 1);
        assertEq(remaining1, 50);
        assertEq(uint256(status1), uint256(OrderStatus.PENDING));

        // Verify shares created match the smaller amount
        assertEq(market.shares(alice, MarketOutcome.YES), 50); // Only 50 shares created
        assertEq(market.shares(bob, MarketOutcome.NO), 50);

        // Verify price sum is correct (40 + 60 = 100)
        uint256 priceSum = 40 + 60;
        assertEq(priceSum, 100);
    }

    /*────────────────────────
        ► BALANCE TESTS
    ────────────────────────*/

    function test_BuyBuy_BalanceChanges() public {
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);
        uint256 marketBalanceBefore = token.balanceOf(address(market));

        // Alice creates a BUY order for YES at price 40
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 40);
        vm.stopPrank();

        // Bob creates a BUY order for NO at price 60
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 60);
        vm.stopPrank();

        // Match orders
        market.matchOrders(alice, bob, 1, 1);

        uint256 aliceBalanceAfter = token.balanceOf(alice);
        uint256 bobBalanceAfter = token.balanceOf(bob);
        uint256 marketBalanceAfter = token.balanceOf(address(market));

        // Calculate costs using the same formula as the contract
        uint256 aliceCost = (100 * 40 * 10 ** token.decimals()) / 100;
        uint256 bobCost = (100 * 60 * 10 ** token.decimals()) / 100;

        // Alice should have paid aliceCost tokens
        assertEq(aliceBalanceAfter, aliceBalanceBefore - aliceCost, "Alice should have paid 40 tokens");

        // Bob should have paid bobCost tokens
        assertEq(bobBalanceAfter, bobBalanceBefore - bobCost, "Bob should have paid 60 tokens");

        // Market should hold total tokens
        assertEq(marketBalanceAfter, marketBalanceBefore + aliceCost + bobCost, "Market should hold 100 tokens");

        // Verify shares were created
        assertEq(market.shares(alice, MarketOutcome.YES), 100);
        assertEq(market.shares(bob, MarketOutcome.NO), 100);
    }

    function test_BuySell_BalanceChanges() public {
        // Setup: Create initial shares through BuyBuy match
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 200, 50);
        vm.stopPrank();

        vm.prank(charlie);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 200, 50);
        vm.stopPrank();

        market.matchOrders(bob, charlie, 1, 1);

        // Now test OrderSide matching
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);
        uint256 marketBalanceBefore = token.balanceOf(address(market));

        // Alice creates a BUY order for YES at price 60
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 60);
        vm.stopPrank();

        // Bob creates a SELL order for YES at price 50
        vm.prank(bob);
        market.createOrder(OrderSide.SELL, MarketOutcome.YES, 100, 50);
        vm.stopPrank();

        // Match orders
        market.matchOrders(alice, bob, 1, 2);

        uint256 aliceBalanceAfter = token.balanceOf(alice);
        uint256 bobBalanceAfter = token.balanceOf(bob);
        uint256 marketBalanceAfter = token.balanceOf(address(market));

        // Calculate amounts using the same formula as the contract
        uint256 aliceEscrow = (100 * 60 * 10 ** token.decimals()) / 100;
        uint256 sellerPayment = (100 * 50 * 10 ** token.decimals()) / 100;
        uint256 refund = (100 * (60 - 50) * 10 ** token.decimals()) / 100;

        // Alice should have net payment of sellerPayment (paid aliceEscrow, got refund)
        assertEq(aliceBalanceAfter, aliceBalanceBefore - sellerPayment, "Alice should have net payment of 50 tokens");

        // Bob should have received sellerPayment tokens
        assertEq(bobBalanceAfter, bobBalanceBefore + sellerPayment, "Bob should have received 50 tokens");

        // Market balance should be unchanged
        assertEq(marketBalanceAfter, marketBalanceBefore, "Market balance should be unchanged");

        // Verify shares transferred
        assertEq(market.shares(alice, MarketOutcome.YES), 100);
        assertEq(market.shares(bob, MarketOutcome.YES), 100); // 200 - 100
    }

    function test_PartialFill_BalanceChanges() public {
        // Setup: Create initial shares
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 150, 50);
        vm.stopPrank();

        vm.prank(charlie);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 150, 50);
        vm.stopPrank();

        market.matchOrders(bob, charlie, 1, 1);

        // Test partial fill balances
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);
        uint256 marketBalanceBefore = token.balanceOf(address(market));

        // Alice creates a BUY order for 100 YES at price 70
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 70);
        vm.stopPrank();

        // Bob creates SELL order for 60 YES at price 50
        vm.prank(bob);
        market.createOrder(OrderSide.SELL, MarketOutcome.YES, 60, 50);
        vm.stopPrank();

        // Match orders (partial fill - only 60 out of 100 shares)
        market.matchOrders(alice, bob, 1, 2);

        uint256 aliceBalanceAfter = token.balanceOf(alice);
        uint256 bobBalanceAfter = token.balanceOf(bob);
        uint256 marketBalanceAfter = token.balanceOf(address(market));

        // Calculate amounts using the same formula as the contract
        uint256 aliceEscrow = (100 * 70 * 10 ** token.decimals()) / 100;
        uint256 bobPayment = (60 * 50 * 10 ** token.decimals()) / 100;

        // Alice paid aliceEscrow total when creating order
        assertEq(aliceBalanceAfter, aliceBalanceBefore - aliceEscrow, "Alice should have paid 70 tokens total");

        // Bob should have received bobPayment tokens
        assertEq(bobBalanceAfter, bobBalanceBefore + bobPayment, "Bob should have received 30 tokens");

        // Market: Alice added aliceEscrow, paid out bobPayment to Bob, NO REFUND to Alice since order is still PENDING
        assertEq(
            marketBalanceAfter,
            marketBalanceBefore + aliceEscrow - bobPayment,
            "Market should hold Alice's full remaining escrow"
        );

        // Verify partial fill
        (, uint256 remaining,,,, OrderStatus status) = market.orders(alice, 1);
        assertEq(remaining, 40, "Alice should have 40 shares remaining");
        assertEq(uint256(status), uint256(OrderStatus.PENDING));
    }

    function test_PriceDifference_RefundCalculation() public {
        // Setup: Create initial shares
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.stopPrank();

        vm.prank(charlie);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        vm.stopPrank();

        market.matchOrders(bob, charlie, 1, 1);

        // Test large price difference
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);

        // Alice creates a BUY order for YES at high price 90
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 90);
        vm.stopPrank();

        // Bob creates a SELL order for YES at low price 30
        vm.prank(bob);
        market.createOrder(OrderSide.SELL, MarketOutcome.YES, 100, 30);
        vm.stopPrank();

        // Match orders
        market.matchOrders(alice, bob, 1, 2);

        uint256 aliceBalanceAfter = token.balanceOf(alice);
        uint256 bobBalanceAfter = token.balanceOf(bob);

        // Calculate amounts using the same formula as the contract
        uint256 sellerPayment = (100 * 30 * 10 ** token.decimals()) / 100;

        // Alice should pay seller's price (30) - she paid 90 upfront, gets 60 refund
        assertEq(aliceBalanceAfter, aliceBalanceBefore - sellerPayment, "Alice should have net payment of 30");

        // Bob should receive sellerPayment tokens
        assertEq(bobBalanceAfter, bobBalanceBefore + sellerPayment, "Bob should have received 30 tokens");
    }

    function test_MultipleMatches_CumulativeBalances() public {
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);
        uint256 charlieBalanceBefore = token.balanceOf(charlie);

        // Create multiple orders and match them
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 50, 40);
        vm.stopPrank();

        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 50, 60);
        vm.stopPrank();

        // First match: BuyBuy
        market.matchOrders(alice, bob, 1, 1);

        // Create second set of orders
        vm.prank(charlie);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 30, 55);
        vm.stopPrank();

        vm.prank(alice);
        market.createOrder(OrderSide.SELL, MarketOutcome.YES, 30, 45);
        vm.stopPrank();

        // Second match: OrderSide
        market.matchOrders(charlie, alice, 1, 2);

        uint256 aliceBalanceAfter = token.balanceOf(alice);
        uint256 bobBalanceAfter = token.balanceOf(bob);
        uint256 charlieBalanceAfter = token.balanceOf(charlie);

        // Calculate amounts using the same formula as the contract
        uint256 aliceFirstCost = (50 * 40 * 10 ** token.decimals()) / 100;
        uint256 aliceReceived = (30 * 45 * 10 ** token.decimals()) / 100;
        uint256 bobCost = (50 * 60 * 10 ** token.decimals()) / 100;
        uint256 charlieNetCost = (30 * 45 * 10 ** token.decimals()) / 100; // pays seller's price after refund

        // Alice: paid aliceFirstCost, received aliceReceived
        assertEq(
            aliceBalanceAfter, aliceBalanceBefore - aliceFirstCost + aliceReceived, "Alice net: paid 20, received 13.5"
        );

        // Bob: paid bobCost
        assertEq(bobBalanceAfter, bobBalanceBefore - bobCost, "Bob should have paid 30");

        // Charlie: net payment is seller's price (paid 55, got 10 refund)
        assertEq(charlieBalanceAfter, charlieBalanceBefore - charlieNetCost, "Charlie net payment should be 13.5");
    }
}
