// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';

interface IEntity is Structure {

    function createCPO(address, bytes5, bool) external view returns (CPO memory);
    function createCS(address, address, bytes3, uint, bool) external view returns (CS memory);
    function createEV(address, uint, uint) external view returns (EV memory);  

}