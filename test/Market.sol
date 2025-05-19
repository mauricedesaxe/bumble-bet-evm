// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Market} from "../src/Market.sol";

contract MarketTest is Test {
    Market public market;

    function setUp() public {
        market = new Market();
        market.setNumber(0);
    }

    function test_Increment() public {
        market.increment();
        assertEq(market.number(), 1);
    }

    function testFuzz_SetNumber(uint256 x) public {
        market.setNumber(x);
        assertEq(market.number(), x);
    }
}
