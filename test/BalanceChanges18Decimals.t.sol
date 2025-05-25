// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Market, OrderSide, MarketOutcome, OrderStatus, Order} from "../src/Market.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {MockERC20} from "../src/__mocks__/MockERC20.sol";

contract BalanceChanges18DecimalsTest is Test {
    IERC20 public token;
    Market public market;
    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);

    function setUp() public {
        // Create token with 18 decimals (like DAI, WETH, etc.)
        token = IERC20(address(new MockERC20("DAI", "DAI", 18)));
        market = new Market("TestMarket", address(token));

        // Set up balances
        token.mint(alice, 10_000 ether);
        token.mint(bob, 10_000 ether);
        token.mint(charlie, 10_000 ether);

        // Set up token allowances
        vm.prank(alice);
        token.approve(address(market), 10_000 ether);

        vm.prank(bob);
        token.approve(address(market), 10_000 ether);

        vm.prank(charlie);
        token.approve(address(market), 10_000 ether);
    }

    function test_SimpleCreateOrder_18Decimals() public {
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 marketBalanceBefore = token.balanceOf(address(market));

        // Alice creates a BUY order for 100 shares at 50 cents
        // Cost = 100 * 50 * 10^18 / 100 = 50 * 10^18 = 50 DAI
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);

        uint256 aliceBalanceAfter = token.balanceOf(alice);
        uint256 marketBalanceAfter = token.balanceOf(address(market));

        // Alice should have paid 50 DAI (50 * 10^18 wei)
        assertEq(aliceBalanceAfter, aliceBalanceBefore - 50 * 10 ** 18, "Alice should have paid 50 DAI");
        assertEq(marketBalanceAfter, marketBalanceBefore + 50 * 10 ** 18, "Market should have received 50 DAI");
    }

    function test_BuyBuyMatch_18Decimals() public {
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);
        uint256 marketBalanceBefore = token.balanceOf(address(market));

        // Alice buys 100 YES shares at 40 cents
        // Cost = 100 * 40 * 10^18 / 100 = 40 * 10^18 = 40 DAI
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 40);

        // Bob buys 100 NO shares at 60 cents
        // Cost = 100 * 60 * 10^18 / 100 = 60 * 10^18 = 60 DAI
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 60);

        // Match orders
        market.matchOrders(alice, bob, 1, 1);

        uint256 aliceBalanceAfter = token.balanceOf(alice);
        uint256 bobBalanceAfter = token.balanceOf(bob);
        uint256 marketBalanceAfter = token.balanceOf(address(market));

        // Verify balances
        assertEq(aliceBalanceAfter, aliceBalanceBefore - 40 * 10 ** 18, "Alice should have paid 40 DAI");
        assertEq(bobBalanceAfter, bobBalanceBefore - 60 * 10 ** 18, "Bob should have paid 60 DAI");
        assertEq(marketBalanceAfter, marketBalanceBefore + 100 * 10 ** 18, "Market should hold 100 DAI total");

        // Verify shares
        assertEq(market.shares(alice, MarketOutcome.YES), 100, "Alice should have 100 YES shares");
        assertEq(market.shares(bob, MarketOutcome.NO), 100, "Bob should have 100 NO shares");
    }

    function test_BuySellMatch_WithRefund_18Decimals() public {
        // First create shares for Bob
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 200, 50);
        vm.prank(charlie);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 200, 50);
        market.matchOrders(bob, charlie, 1, 1);

        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);
        uint256 marketBalanceBefore = token.balanceOf(address(market));

        // Alice buys 100 YES shares at 80 cents (willing to pay high price)
        // Escrow = 100 * 80 * 10^18 / 100 = 80 * 10^18 = 80 DAI
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 80);

        // Bob sells 100 YES shares at 50 cents
        vm.prank(bob);
        market.createOrder(OrderSide.SELL, MarketOutcome.YES, 100, 50);

        // Match orders
        market.matchOrders(alice, bob, 1, 2);

        uint256 aliceBalanceAfter = token.balanceOf(alice);
        uint256 bobBalanceAfter = token.balanceOf(bob);
        uint256 marketBalanceAfter = token.balanceOf(address(market));

        // Alice pays seller's price (50) and gets refund of (80-50) = 30
        // Net payment = 50 DAI
        assertEq(aliceBalanceAfter, aliceBalanceBefore - 50 * 10 ** 18, "Alice should have net payment of 50 DAI");

        // Bob receives 50 DAI
        assertEq(bobBalanceAfter, bobBalanceBefore + 50 * 10 ** 18, "Bob should have received 50 DAI");

        // Market balance unchanged (Alice paid 80, Bob got 50, Alice refunded 30)
        assertEq(marketBalanceAfter, marketBalanceBefore, "Market balance should be unchanged");

        // Verify shares
        assertEq(market.shares(alice, MarketOutcome.YES), 100, "Alice should have 100 YES shares");
        assertEq(market.shares(bob, MarketOutcome.YES), 100, "Bob should have 100 YES shares (200-100)");
    }

    function test_PartialFill_18Decimals() public {
        // Create shares for Bob
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 150, 50);
        vm.prank(charlie);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 150, 50);
        market.matchOrders(bob, charlie, 1, 1);

        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);
        uint256 marketBalanceBefore = token.balanceOf(address(market));

        // Alice wants to buy 100 YES shares at 70 cents
        // Escrow = 100 * 70 * 10^18 / 100 = 70 * 10^18 = 70 DAI
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 70);

        // Bob only sells 60 YES shares at 50 cents
        vm.prank(bob);
        market.createOrder(OrderSide.SELL, MarketOutcome.YES, 60, 50);

        // Match orders (partial fill)
        market.matchOrders(alice, bob, 1, 2);

        uint256 aliceBalanceAfter = token.balanceOf(alice);
        uint256 bobBalanceAfter = token.balanceOf(bob);
        uint256 marketBalanceAfter = token.balanceOf(address(market));

        // Alice paid 70 DAI upfront (full escrow for 100 shares)
        assertEq(aliceBalanceAfter, aliceBalanceBefore - 70 * 10 ** 18, "Alice should have paid 70 DAI upfront");

        // Bob receives payment for 60 shares at 50 cents = 30 DAI
        assertEq(bobBalanceAfter, bobBalanceBefore + 30 * 10 ** 18, "Bob should have received 30 DAI");

        // Market holds Alice's remaining escrow: 70 - 30 = 40 DAI
        assertEq(marketBalanceAfter, marketBalanceBefore + 40 * 10 ** 18, "Market should hold 40 DAI in escrow");

        // Verify partial fill
        (, uint256 remaining,,,, OrderStatus status) = market.orders(alice, 1);
        assertEq(remaining, 40, "Alice should have 40 shares remaining to buy");
        assertEq(uint256(status), uint256(OrderStatus.PENDING), "Alice's order should still be PENDING");

        // Verify shares
        assertEq(market.shares(alice, MarketOutcome.YES), 60, "Alice should have 60 YES shares");
        assertEq(market.shares(bob, MarketOutcome.YES), 90, "Bob should have 90 YES shares (150-60)");
    }

    function test_CancelOrder_RefundFull_18Decimals() public {
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 marketBalanceBefore = token.balanceOf(address(market));

        // Alice creates order for 250 shares at 75 cents
        // Cost = 250 * 75 * 10^18 / 100 = 187.5 * 10^18 = 187.5 DAI
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 250, 75);

        // Verify escrow
        assertEq(token.balanceOf(alice), aliceBalanceBefore - 187.5 * 10 ** 18, "Alice should have paid 187.5 DAI");
        assertEq(
            token.balanceOf(address(market)), marketBalanceBefore + 187.5 * 10 ** 18, "Market should hold 187.5 DAI"
        );

        // Alice cancels the order
        vm.prank(alice);
        market.cancelOrder(1);

        // Verify full refund
        assertEq(token.balanceOf(alice), aliceBalanceBefore, "Alice should get full refund");
        assertEq(token.balanceOf(address(market)), marketBalanceBefore, "Market should return to original balance");
    }

    function test_LargeAmounts_18Decimals() public {
        // Test with large share amounts to ensure no overflow
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);

        // Alice buys 10,000 YES shares at 25 cents
        // Cost = 10,000 * 25 * 10^18 / 100 = 2,500 * 10^18 = 2,500 DAI
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 10_000, 25);

        // Bob buys 10,000 NO shares at 75 cents
        // Cost = 10,000 * 75 * 10^18 / 100 = 7,500 * 10^18 = 7,500 DAI
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 10_000, 75);

        // Match orders
        market.matchOrders(alice, bob, 1, 1);

        // Verify balances
        assertEq(token.balanceOf(alice), aliceBalanceBefore - 2_500 * 10 ** 18, "Alice should have paid 2,500 DAI");
        assertEq(token.balanceOf(bob), bobBalanceBefore - 7_500 * 10 ** 18, "Bob should have paid 7,500 DAI");

        // Verify shares
        assertEq(market.shares(alice, MarketOutcome.YES), 10_000, "Alice should have 10,000 YES shares");
        assertEq(market.shares(bob, MarketOutcome.NO), 10_000, "Bob should have 10,000 NO shares");
    }

    function test_SmallPrices_18Decimals() public {
        // Test with 1 cent price (edge case)
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);

        // Alice buys 1000 YES shares at 1 cent
        // Cost = 1000 * 1 * 10^18 / 100 = 10 * 10^18 = 10 DAI
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 1000, 1);

        // Bob buys 1000 NO shares at 99 cents
        // Cost = 1000 * 99 * 10^18 / 100 = 990 * 10^18 = 990 DAI
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 1000, 99);

        // Match orders
        market.matchOrders(alice, bob, 1, 1);

        // Verify balances
        assertEq(token.balanceOf(alice), aliceBalanceBefore - 10 * 10 ** 18, "Alice should have paid 10 DAI");
        assertEq(token.balanceOf(bob), bobBalanceBefore - 990 * 10 ** 18, "Bob should have paid 990 DAI");

        // Verify shares
        assertEq(market.shares(alice, MarketOutcome.YES), 1000, "Alice should have 1000 YES shares");
        assertEq(market.shares(bob, MarketOutcome.NO), 1000, "Bob should have 1000 NO shares");
    }
}
