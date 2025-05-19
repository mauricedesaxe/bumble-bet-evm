// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Order, BuySell, YesNo} from "./Market.sol";

library OrderUtils {
    function isBuySell(Order storage order1, Order storage order2) internal view returns (bool) {
        return order1.side == BuySell.BUY && order2.side == BuySell.SELL;
    }

    function isBuyBuy(Order storage order1, Order storage order2) internal view returns (bool) {
        return order1.side == BuySell.BUY && order2.side == BuySell.BUY;
    }

    function isYesYes(Order storage order1, Order storage order2) internal view returns (bool) {
        return order1.yesNo == YesNo.YES && order2.yesNo == YesNo.YES;
    }

    function isNoNo(Order storage order1, Order storage order2) internal view returns (bool) {
        return order1.yesNo == YesNo.NO && order2.yesNo == YesNo.NO;
    }

    function isYesNo(Order storage order1, Order storage order2) internal view returns (bool) {
        return order1.yesNo == YesNo.YES && order2.yesNo == YesNo.NO;
    }
}
