// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Market, BuySell, YesNo, OrderStatus, Order} from "../src/Market.sol";
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
}
