// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Order, OrderSide, MarketOutcome} from "./Market.sol";

library OrderUtils {
    function isBuySell(Order storage order1, Order storage order2) internal view returns (bool) {
        return order1.side == OrderSide.BUY && order2.side == OrderSide.SELL;
    }

    function isBuyBuy(Order storage order1, Order storage order2) internal view returns (bool) {
        return order1.side == OrderSide.BUY && order2.side == OrderSide.BUY;
    }

    function isYesYes(Order storage order1, Order storage order2) internal view returns (bool) {
        return order1.yesNo == MarketOutcome.YES && order2.yesNo == MarketOutcome.YES;
    }

    function isNoNo(Order storage order1, Order storage order2) internal view returns (bool) {
        return order1.yesNo == MarketOutcome.NO && order2.yesNo == MarketOutcome.NO;
    }

    function isYesNo(Order storage order1, Order storage order2) internal view returns (bool) {
        return order1.yesNo == MarketOutcome.YES && order2.yesNo == MarketOutcome.NO;
    }
}
