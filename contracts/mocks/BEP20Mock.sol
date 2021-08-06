// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../libraries/BEP20.sol";

contract BEP20Mock is BEP20{
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) BEP20(name, symbol) {
        _mint(msg.sender, supply);
    }
}