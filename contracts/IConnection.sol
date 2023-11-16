// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';

interface IConnection is Structure {

    function connect(address, address, uint) external view returns (Connection memory);
    function disconnect(address, address) external view returns (Connection memory);
    
}