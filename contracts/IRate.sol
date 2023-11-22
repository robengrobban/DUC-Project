// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';

interface IRate is Structure {

    function setRates(address, bytes3, uint[RATE_SLOTS] calldata, uint, uint) external view returns (Rate memory);
    function transferToNewRates(Rate memory) external view returns (Rate memory);

    function getNextRateChange() external view returns (uint);

}