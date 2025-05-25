// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Market, OrderSide, MarketOutcome, OrderStatus, Order} from "../src/Market.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {MockERC20} from "../src/__mocks__/MockERC20.sol";

contract ClaimTest is Test {
    IERC20 public token;
    Market public market;
    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);
    address dave = address(0x4);

    function setUp() public {
        token = IERC20(address(new MockERC20("Token", "TKN", 6)));
        market = new Market("TestMarket", address(token));

        // Set up balances
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
        vm.deal(dave, 100 ether);

        // Set up token balances
        token.mint(address(this), 1000 ether);
        token.mint(alice, 100 ether);
        token.mint(bob, 100 ether);
        token.mint(charlie, 100 ether);
        token.mint(dave, 100 ether);

        // Set up token allowances
        token.approve(address(market), 1000 ether);

        vm.startPrank(alice);
        token.approve(address(market), 100 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(market), 100 ether);
        vm.stopPrank();

        vm.startPrank(charlie);
        token.approve(address(market), 100 ether);
        vm.stopPrank();

        vm.startPrank(dave);
        token.approve(address(market), 100 ether);
        vm.stopPrank();
    }

    /*────────────────────────
        ► BASIC CLAIM TESTS
    ────────────────────────*/

    function test_Claim_WinnerWithShares_Success() public {
        // Create shares for alice (YES) and bob (NO)
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        market.matchOrders(alice, bob, 1, 1);

        // Resolve market to YES (alice wins)
        market.resolveMarket(MarketOutcome.YES);

        // Record balances before claim
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 aliceYesSharesBefore = market.shares(alice, MarketOutcome.YES);
        uint256 aliceNoSharesBefore = market.shares(alice, MarketOutcome.NO);

        // Alice claims
        vm.prank(alice);
        market.claim();

        // Verify payout
        uint256 expectedPayout = aliceYesSharesBefore * (10 ** token.decimals());
        assertEq(token.balanceOf(alice), aliceBalanceBefore + expectedPayout, "Alice should receive correct payout");

        // Verify shares are zeroed
        assertEq(market.shares(alice, MarketOutcome.YES), 0, "Alice YES shares should be zero");
        assertEq(market.shares(alice, MarketOutcome.NO), 0, "Alice NO shares should be zero");
    }

    function test_Claim_LoserWithShares_Success() public {
        // Create shares for alice (YES) and bob (NO)
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        market.matchOrders(alice, bob, 1, 1);

        // Resolve market to YES (bob loses)
        market.resolveMarket(MarketOutcome.YES);

        // Record balances before claim
        uint256 bobBalanceBefore = token.balanceOf(bob);
        uint256 bobNoSharesBefore = market.shares(bob, MarketOutcome.NO);

        // Bob claims (loser)
        vm.prank(bob);
        market.claim();

        // Verify no payout
        assertEq(token.balanceOf(bob), bobBalanceBefore, "Bob should receive no payout");

        // Verify shares are zeroed
        assertEq(market.shares(bob, MarketOutcome.YES), 0, "Bob YES shares should be zero");
        assertEq(market.shares(bob, MarketOutcome.NO), 0, "Bob NO shares should be zero");
    }

    function test_Claim_NoShares_Success() public {
        // Resolve market without any shares created
        market.resolveMarket(MarketOutcome.YES);

        // Record balance before claim
        uint256 charlieBalanceBefore = token.balanceOf(charlie);

        // Charlie claims with no shares
        vm.prank(charlie);
        market.claim();

        // Verify no payout and no revert
        assertEq(token.balanceOf(charlie), charlieBalanceBefore, "Charlie should receive no payout");
        assertEq(market.shares(charlie, MarketOutcome.YES), 0, "Charlie YES shares should remain zero");
        assertEq(market.shares(charlie, MarketOutcome.NO), 0, "Charlie NO shares should remain zero");
    }

    function test_Claim_BeforeResolution_Reverts() public {
        // Create shares for alice
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        market.matchOrders(alice, bob, 1, 1);

        // Try to claim before resolution
        vm.prank(alice);
        vm.expectRevert("Market is not resolved");
        market.claim();
    }

    /*────────────────────────────────
        ► PAYOUT CALCULATION TESTS
    ────────────────────────────────*/

    function test_Claim_CorrectPayoutAmount() public {
        // Test with various share amounts
        uint256[] memory shareAmounts = new uint256[](4);
        shareAmounts[0] = 1;
        shareAmounts[1] = 100;
        shareAmounts[2] = 1000;
        shareAmounts[3] = 12345;

        for (uint256 i = 0; i < shareAmounts.length; i++) {
            uint256 shares = shareAmounts[i];

            // Create shares
            vm.prank(alice);
            market.createOrder(OrderSide.BUY, MarketOutcome.YES, shares, 50);
            vm.prank(bob);
            market.createOrder(OrderSide.BUY, MarketOutcome.NO, shares, 50);
            market.matchOrders(alice, bob, i + 1, i + 1);
        }

        // Resolve to YES
        market.resolveMarket(MarketOutcome.YES);

        // Calculate total shares and expected payout
        uint256 totalShares = 1 + 100 + 1000 + 12345;
        uint256 expectedPayout = totalShares * (10 ** token.decimals());
        uint256 aliceBalanceBefore = token.balanceOf(alice);

        // Claim
        vm.prank(alice);
        market.claim();

        // Verify correct payout
        assertEq(token.balanceOf(alice), aliceBalanceBefore + expectedPayout, "Payout should match formula");
    }

    function test_Claim_LargeShareAmount() public {
        // Test with maximum realistic share amount
        uint256 largeShares = 1_000_000;

        // Create shares
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, largeShares, 50);
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, largeShares, 50);
        market.matchOrders(alice, bob, 1, 1);

        // Resolve to YES
        market.resolveMarket(MarketOutcome.YES);

        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 expectedPayout = largeShares * (10 ** token.decimals());

        // Claim
        vm.prank(alice);
        market.claim();

        // Verify no overflow and correct transfer
        assertEq(token.balanceOf(alice), aliceBalanceBefore + expectedPayout, "Large payout should work correctly");
    }

    /*────────────────────────────────
        ► MULTIPLE USERS TESTS
    ────────────────────────────────*/

    function test_Claim_MultipleWinners() public {
        // Create shares for multiple users
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        market.matchOrders(alice, bob, 1, 1);

        vm.prank(charlie);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 200, 40);
        vm.prank(dave);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 200, 60);
        market.matchOrders(charlie, dave, 1, 1);

        // Resolve to YES (alice and charlie win)
        market.resolveMarket(MarketOutcome.YES);

        // Record balances
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 charlieBalanceBefore = token.balanceOf(charlie);
        uint256 marketBalanceBefore = token.balanceOf(address(market));

        // Both winners claim
        vm.prank(alice);
        market.claim();

        vm.prank(charlie);
        market.claim();

        // Verify payouts
        assertEq(token.balanceOf(alice), aliceBalanceBefore + 100 * (10 ** token.decimals()), "Alice payout correct");
        assertEq(
            token.balanceOf(charlie), charlieBalanceBefore + 200 * (10 ** token.decimals()), "Charlie payout correct"
        );

        // Verify market had sufficient balance
        uint256 totalPayout = 300 * (10 ** token.decimals());
        assertEq(
            token.balanceOf(address(market)), marketBalanceBefore - totalPayout, "Market balance decreased correctly"
        );
    }

    function test_Claim_MixedWinnersAndLosers() public {
        // Create shares for multiple users
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        market.matchOrders(alice, bob, 1, 1);

        vm.prank(charlie);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 200, 60);
        vm.prank(dave);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 200, 40);
        market.matchOrders(charlie, dave, 1, 1);

        // Resolve to NO (bob and dave win)
        market.resolveMarket(MarketOutcome.NO);

        // Record balances
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);
        uint256 charlieBalanceBefore = token.balanceOf(charlie);
        uint256 daveBalanceBefore = token.balanceOf(dave);

        // All users claim
        vm.prank(alice);
        market.claim();

        vm.prank(bob);
        market.claim();

        vm.prank(charlie);
        market.claim();

        vm.prank(dave);
        market.claim();

        // Verify only winners receive payouts
        assertEq(token.balanceOf(alice), aliceBalanceBefore, "Alice (loser) no payout");
        assertEq(token.balanceOf(bob), bobBalanceBefore + 100 * (10 ** token.decimals()), "Bob (winner) gets payout");
        assertEq(token.balanceOf(charlie), charlieBalanceBefore, "Charlie (loser) no payout");
        assertEq(token.balanceOf(dave), daveBalanceBefore + 200 * (10 ** token.decimals()), "Dave (winner) gets payout");

        // Verify all shares are zeroed
        assertEq(market.shares(alice, MarketOutcome.YES), 0);
        assertEq(market.shares(alice, MarketOutcome.NO), 0);
        assertEq(market.shares(bob, MarketOutcome.YES), 0);
        assertEq(market.shares(bob, MarketOutcome.NO), 0);
        assertEq(market.shares(charlie, MarketOutcome.YES), 0);
        assertEq(market.shares(charlie, MarketOutcome.NO), 0);
        assertEq(market.shares(dave, MarketOutcome.YES), 0);
        assertEq(market.shares(dave, MarketOutcome.NO), 0);
    }

    /*────────────────────────
        ► EDGE CASES
    ────────────────────────*/

    function test_Claim_BothYesAndNoShares() public {
        // Create a scenario where alice has both YES and NO shares
        // First match: alice gets YES shares
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        market.matchOrders(alice, bob, 1, 1);

        // Second match: alice gets NO shares
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 50, 60);
        vm.prank(charlie);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 50, 40);
        market.matchOrders(charlie, alice, 1, 2);

        // Verify alice has both types of shares
        assertEq(market.shares(alice, MarketOutcome.YES), 100);
        assertEq(market.shares(alice, MarketOutcome.NO), 50);

        // Resolve to YES
        market.resolveMarket(MarketOutcome.YES);

        uint256 aliceBalanceBefore = token.balanceOf(alice);

        // Alice claims
        vm.prank(alice);
        market.claim();

        // Verify only YES shares pay out
        uint256 expectedPayout = 100 * (10 ** token.decimals());
        assertEq(token.balanceOf(alice), aliceBalanceBefore + expectedPayout, "Only winning shares should pay out");

        // Verify both share types are zeroed
        assertEq(market.shares(alice, MarketOutcome.YES), 0);
        assertEq(market.shares(alice, MarketOutcome.NO), 0);
    }

    function test_Claim_MultipleClaims() public {
        // Create shares for alice
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        market.matchOrders(alice, bob, 1, 1);

        // Resolve to YES
        market.resolveMarket(MarketOutcome.YES);

        uint256 aliceBalanceBefore = token.balanceOf(alice);

        // First claim
        vm.prank(alice);
        market.claim();

        uint256 aliceBalanceAfterFirst = token.balanceOf(alice);
        assertEq(
            aliceBalanceAfterFirst, aliceBalanceBefore + 100 * (10 ** token.decimals()), "First claim should pay out"
        );

        // Second claim
        vm.prank(alice);
        market.claim();

        // Balance should not change after second claim
        assertEq(token.balanceOf(alice), aliceBalanceAfterFirst, "Second claim should have no effect");
        assertEq(market.shares(alice, MarketOutcome.YES), 0, "Shares should remain zero");
        assertEq(market.shares(alice, MarketOutcome.NO), 0, "Shares should remain zero");
    }

    function test_Claim_AfterPartialFills() public {
        // Create partial fill scenario
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 150, 50);
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        market.matchOrders(alice, bob, 1, 1);

        // Alice has 100 YES shares from partial fill
        assertEq(market.shares(alice, MarketOutcome.YES), 100);

        // Add more shares through another match
        vm.prank(charlie);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 50, 50);
        market.matchOrders(alice, charlie, 1, 1);

        // Alice now has 150 YES shares total
        assertEq(market.shares(alice, MarketOutcome.YES), 150);

        // Resolve to YES
        market.resolveMarket(MarketOutcome.YES);

        uint256 aliceBalanceBefore = token.balanceOf(alice);

        // Claim
        vm.prank(alice);
        market.claim();

        // Verify correct payout for fractional shares
        uint256 expectedPayout = 150 * (10 ** token.decimals());
        assertEq(
            token.balanceOf(alice), aliceBalanceBefore + expectedPayout, "Partial fill shares should pay out correctly"
        );
    }

    /*────────────────────────────────
        ► MARKET BALANCE TESTS
    ────────────────────────────────*/

    function test_Claim_MarketBalanceAccounting() public {
        // Create multiple matches to build up market balance
        uint256 totalYesShares = 0;
        uint256 totalNoShares = 0;

        // Match 1
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        market.matchOrders(alice, bob, 1, 1);
        totalYesShares += 100;
        totalNoShares += 100;

        // Match 2
        vm.prank(charlie);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 200, 60);
        vm.prank(dave);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 200, 40);
        market.matchOrders(charlie, dave, 1, 1);
        totalYesShares += 200;
        totalNoShares += 200;

        // Create some pending orders to leave funds in market
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 50, 70);

        uint256 marketBalanceBefore = token.balanceOf(address(market));

        // Resolve to YES
        market.resolveMarket(MarketOutcome.YES);

        // All winners claim
        vm.prank(alice);
        market.claim();

        vm.prank(charlie);
        market.claim();

        uint256 marketBalanceAfter = token.balanceOf(address(market));
        uint256 totalPayout = totalYesShares * (10 ** token.decimals());

        // Verify market balance decreased by exact payout amount
        assertEq(
            marketBalanceAfter, marketBalanceBefore - totalPayout, "Market balance should decrease by total payouts"
        );

        // Verify market retains funds from pending orders
        assertGt(marketBalanceAfter, 0, "Market should retain funds from pending orders");
    }

    /*────────────────────────────────
        ► INTEGRATION TESTS
    ────────────────────────────────*/

    function test_Claim_WithPendingOrders() public {
        // Create shares for alice
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        market.matchOrders(alice, bob, 1, 1);

        // Create pending order for alice
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 50, 60);

        // Resolve to YES
        market.resolveMarket(MarketOutcome.YES);

        // Claim shares
        vm.prank(alice);
        market.claim();

        // Verify alice can still cancel pending order
        vm.prank(alice);
        market.cancelOrder(2);

        // Verify order cancelled
        (,,,,, OrderStatus status) = market.orders(alice, 2);
        assertEq(uint256(status), uint256(OrderStatus.CANCELLED), "Pending order should be cancellable after claim");
    }

    function test_Claim_FullLifecycle() public {
        // Complete lifecycle test
        uint256 aliceInitialBalance = token.balanceOf(alice);
        uint256 bobInitialBalance = token.balanceOf(bob);

        // 1. Create orders
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 60);

        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 40);

        // 2. Match orders
        market.matchOrders(alice, bob, 1, 1);

        // 3. Create and match more orders
        vm.prank(alice);
        market.createOrder(OrderSide.SELL, MarketOutcome.YES, 50, 50);

        vm.prank(charlie);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 50, 50);

        market.matchOrders(charlie, alice, 1, 2);

        // 4. Resolve market
        market.resolveMarket(MarketOutcome.YES);

        // 5. All users claim
        vm.prank(alice);
        market.claim();

        vm.prank(bob);
        market.claim();

        vm.prank(charlie);
        market.claim();

        // 6. Verify final state
        // Alice: bought 100 YES at 60, sold 50 YES at 50, won with 50 YES
        uint256 aliceCost = (100 * 60 * 10 ** token.decimals()) / 100;
        uint256 aliceRevenue = (50 * 50 * 10 ** token.decimals()) / 100;
        uint256 alicePayout = 50 * (10 ** token.decimals());
        assertEq(
            token.balanceOf(alice),
            aliceInitialBalance - aliceCost + aliceRevenue + alicePayout,
            "Alice final balance incorrect"
        );

        // Bob: bought 100 NO at 40, lost
        uint256 bobCost = (100 * 40 * 10 ** token.decimals()) / 100;
        assertEq(token.balanceOf(bob), bobInitialBalance - bobCost, "Bob final balance incorrect");

        // Verify all shares are zeroed
        assertEq(market.shares(alice, MarketOutcome.YES), 0);
        assertEq(market.shares(alice, MarketOutcome.NO), 0);
        assertEq(market.shares(bob, MarketOutcome.YES), 0);
        assertEq(market.shares(bob, MarketOutcome.NO), 0);
        assertEq(market.shares(charlie, MarketOutcome.YES), 0);
        assertEq(market.shares(charlie, MarketOutcome.NO), 0);
    }

    /*────────────────────────────────
        ► FUZZ TESTS
    ────────────────────────────────*/

    function testFuzz_Claim_RandomShares(uint256 shares, bool outcomeIsYes) public {
        shares = bound(shares, 1, 1_000_000);

        // Create shares
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, shares, 50);
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, shares, 50);
        market.matchOrders(alice, bob, 1, 1);

        // Resolve market
        MarketOutcome outcome = outcomeIsYes ? MarketOutcome.YES : MarketOutcome.NO;
        market.resolveMarket(outcome);

        // Record balances
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);

        // Both claim
        vm.prank(alice);
        market.claim();

        vm.prank(bob);
        market.claim();

        // Verify correct payouts
        if (outcomeIsYes) {
            assertEq(token.balanceOf(alice), aliceBalanceBefore + shares * (10 ** token.decimals()));
            assertEq(token.balanceOf(bob), bobBalanceBefore);
        } else {
            assertEq(token.balanceOf(alice), aliceBalanceBefore);
            assertEq(token.balanceOf(bob), bobBalanceBefore + shares * (10 ** token.decimals()));
        }
    }

    function testFuzz_Claim_TokenDecimals(uint8 decimals) public {
        decimals = uint8(bound(decimals, 0, 18));

        // Create new market with token of different decimals
        MockERC20 customToken = new MockERC20("Custom", "CUST", decimals);
        Market customMarket = new Market("CustomMarket", address(customToken));

        // Setup
        customToken.mint(alice, 1000 * 10 ** decimals);
        customToken.mint(bob, 1000 * 10 ** decimals);

        vm.prank(alice);
        customToken.approve(address(customMarket), 1000 * 10 ** decimals);
        vm.prank(bob);
        customToken.approve(address(customMarket), 1000 * 10 ** decimals);

        // Create shares
        vm.prank(alice);
        customMarket.createOrder(OrderSide.BUY, MarketOutcome.YES, 10, 50);
        vm.prank(bob);
        customMarket.createOrder(OrderSide.BUY, MarketOutcome.NO, 10, 50);
        customMarket.matchOrders(alice, bob, 1, 1);

        // Resolve and claim
        customMarket.resolveMarket(MarketOutcome.YES);

        uint256 aliceBalanceBefore = customToken.balanceOf(alice);

        vm.prank(alice);
        customMarket.claim();

        // Verify payout calculation works with different decimals
        uint256 expectedPayout = 10 * (10 ** decimals);
        assertEq(
            customToken.balanceOf(alice), aliceBalanceBefore + expectedPayout, "Payout should work with custom decimals"
        );
    }

    /*────────────────────────────────
        ► SECURITY TESTS
    ────────────────────────────────*/

    function test_Claim_OnlyShareHolder() public {
        // Create shares for alice
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        market.matchOrders(alice, bob, 1, 1);

        // Resolve to YES
        market.resolveMarket(MarketOutcome.YES);

        // Charlie (non-shareholder) claims - should succeed but get nothing
        uint256 charlieBalanceBefore = token.balanceOf(charlie);
        vm.prank(charlie);
        market.claim();

        assertEq(token.balanceOf(charlie), charlieBalanceBefore, "Non-shareholder should get no payout");

        // Alice's shares should still be there
        assertEq(market.shares(alice, MarketOutcome.YES), 100, "Alice's shares should be unaffected");

        // Alice can still claim her own shares
        vm.prank(alice);
        market.claim();

        assertEq(market.shares(alice, MarketOutcome.YES), 0, "Alice's shares should be claimed");
    }
}
