// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';

interface IEntity is Structure {

    function createCPO(address CPOaddress, bytes5 name) external view returns (CPO memory);
    function createCS(address CPOaddress, address CSaddress, bytes3 region, uint powerDischarge) external view returns (CS memory);
    function createEV(address EVaddress, uint maxCapacity, uint batteryEfficiency) external view returns (EV memory);  

}