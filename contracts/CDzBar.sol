// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./CDzToken.sol";

// @notice CDzBar the rewarder of MasterChef
contract CDzBar is Ownable {
    // @notice The CDz token
    CDzToken public cdz;

    constructor (CDzToken _cdz) {
        cdz = _cdz;
    }

    // @notice Safe cdz transfer function, just in case if rounding error causes pool to not hava enough CDZs
    function safeCDzTransfer(address _to, uint256 _amount) public onlyOwner {
        uint256 cdzBal = cdz.balanceOf(address(this));
        if (_amount > cdzBal) {
            cdz.transfer(_to, cdzBal);
        } else {
            cdz.transfer(_to, _amount);
        }
    }
}