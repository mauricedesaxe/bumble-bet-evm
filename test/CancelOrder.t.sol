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

    // Test successful order cancellation
    function test_Market_CancelOrder() public {
        uint256 balanceBefore = token.balanceOf(address(this));
        uint256 marketBalanceBefore = token.balanceOf(address(market));

        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 100, 50);
        assertEq(market.orderCount(address(this)), 1);

        market.cancelOrder(1);

        uint256 balanceAfter = token.balanceOf(address(this));
        uint256 marketBalanceAfter = token.balanceOf(address(market));

        assertEq(balanceAfter, balanceBefore);
        assertEq(marketBalanceAfter, marketBalanceBefore);

        (,,,,,, OrderStatus status) = market.orders(address(this), 1);

        assertEq(uint256(status), uint256(OrderStatus.CANCELLED));
    }

    // Fuzz test with different order parameters
    function testFuzz_Market_CancelOrder(uint256 amount, uint256 price) public {
        // Limit values to reasonable ranges to avoid overflow and insufficient balance
        price = bound(price, 1, 99); // 100%
        amount = bound(amount, 1, 100 ether * 100 / price);

        uint256 balanceBefore = token.balanceOf(address(this));
        uint256 marketBalanceBefore = token.balanceOf(address(market));

        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, amount, price);
        market.cancelOrder(1);

        uint256 balanceAfter = token.balanceOf(address(this));
        uint256 marketBalanceAfter = token.balanceOf(address(market));

        assertEq(balanceAfter, balanceBefore);
        assertEq(marketBalanceAfter, marketBalanceBefore);

        (,,,,,, OrderStatus status) = market.orders(address(this), 1);

        assertEq(uint256(status), uint256(OrderStatus.CANCELLED));
    }

    // Test canceling multiple orders
    function test_Market_CancelMultipleOrders() public {
        uint256 balanceBefore = token.balanceOf(address(this));
        uint256 marketBalanceBefore = token.balanceOf(address(market));

        // Create three orders
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 100, 50);
        market.createOrder(BuySell.BUY, YesNo.NO, LimitMarket.LIMIT, 200, 75);
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.MARKET, 300, 100);

        // Cancel first and third orders
        market.cancelOrder(1);
        market.cancelOrder(3);

        uint256 balanceAfter = token.balanceOf(address(this));
        uint256 marketBalanceAfter = token.balanceOf(address(market));

        // Order 2 is still pending, so its cost (200 * 75 / 100 = 150) should still be in escrow
        uint256 expectedBalance = balanceBefore - (200 * 75 / 100);
        uint256 expectedMarketBalance = marketBalanceBefore + (200 * 75 / 100);

        assertEq(balanceAfter, expectedBalance);
        assertEq(marketBalanceAfter, expectedMarketBalance);

        (,,,,,, OrderStatus status1) = market.orders(address(this), 1);
        (,,,,,, OrderStatus status2) = market.orders(address(this), 2);
        (,,,,,, OrderStatus status3) = market.orders(address(this), 3);

        assertEq(uint256(status1), uint256(OrderStatus.CANCELLED));
        assertEq(uint256(status2), uint256(OrderStatus.PENDING));
        assertEq(uint256(status3), uint256(OrderStatus.CANCELLED));
    }

    // Test canceling non-existent order
    function test_Market_CancelNonExistentOrder() public {
        vm.expectRevert("Order does not exist");
        market.cancelOrder(999);
    }

    // Test canceling a non-pending order
    function test_Market_CancelNonPendingOrder() public {
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 100, 50);

        market.cancelOrder(1);

        vm.expectRevert("Cannot cancel a non-pending order");
        market.cancelOrder(1);
    }

    function test_DoubleCancel() public {
        market.createOrder(BuySell.BUY, YesNo.YES, LimitMarket.LIMIT, 10, 10);
        market.cancelOrder(1);

        // second cancel must revert
        vm.expectRevert("Cannot cancel a non-pending order");
        market.cancelOrder(1);
    }
}
