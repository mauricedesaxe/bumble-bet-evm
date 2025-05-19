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
}
