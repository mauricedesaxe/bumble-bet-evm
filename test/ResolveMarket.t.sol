// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Market, OrderSide, MarketOutcome, OrderStatus, Order} from "../src/Market.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {MockERC20} from "../src/__mocks__/MockERC20.sol";

contract MarketTest is Test {
    IERC20 public token;
    Market public market;
    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);
    address carol = address(0xCC);

    function setUp() public {
        token = IERC20(address(new MockERC20("Token", "TKN")));
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

    // Test successful market resolution
    function test_Market_resolveMarket() public {
        uint256 marketBalanceBefore = token.balanceOf(address(market));

        // Alice creates a BUY order for YES
        vm.prank(alice);
        market.createOrder(OrderSide.BUY, MarketOutcome.YES, 100, 50);
        vm.stopPrank();

        // Bob creates a BUY order for NO
        vm.prank(bob);
        market.createOrder(OrderSide.BUY, MarketOutcome.NO, 100, 50);
        vm.stopPrank();

        // Match orders
        market.matchOrders(alice, bob, 1, 1);

        // Verify orders are filled and shares are created
        (,,,,, OrderStatus status1) = market.orders(alice, 1);
        (,,,,, OrderStatus status2) = market.orders(bob, 1);
        assertEq(uint256(status1), uint256(OrderStatus.FILLED));
        assertEq(uint256(status2), uint256(OrderStatus.FILLED));
        assertEq(market.shares(alice, MarketOutcome.YES), 100);
        assertEq(market.shares(bob, MarketOutcome.NO), 100);

        // Resolve market with YES outcome
        market.resolveMarket(MarketOutcome.YES);
        assertEq(market.resolved(), true);
        assertTrue(market.outcome() == MarketOutcome.YES);

        // Claim shares
        vm.prank(alice);
        market.claim();
        assertEq(token.balanceOf(alice), 100 ether);

        assertEq(token.balanceOf(address(market)), marketBalanceBefore);
    }
}
