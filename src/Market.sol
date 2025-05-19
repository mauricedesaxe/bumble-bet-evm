// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Market {
    string public name;
    address public owner;

    constructor(string memory _name) {
        name = _name;
        owner = msg.sender;
    }
}
