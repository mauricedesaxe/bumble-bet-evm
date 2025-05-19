// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Market} from "../src/Market.sol";

contract MarketTest is Test {
    Market public market;

    function setUp() public {
        market = new Market("Market");
    }

    function test_Market() public view {
        assertEq(market.name(), "Market");
    }
}
