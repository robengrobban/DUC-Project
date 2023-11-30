// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';

interface IRate is Structure {

    function setRates(address, bytes3, uint[RATE_SLOTS] calldata, uint, uint) external returns (Rate memory);
    function transferToNewRates(Rate memory) external returns (Rate memory);
    function nextRoaming(address, bytes3, uint, uint) external returns (Rate memory);
    function updateAutomaticRates() external;

}