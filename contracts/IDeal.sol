// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';

interface IDeal is Structure {

    function proposeDeal(address, address, uint) external view returns (Deal memory);
    function verifyRevertProposedDeal(address, address, uint, Deal memory) external view;
    function verifyRespondDeal(address, address, uint, Deal memory) external view;
    
}