// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';

interface IDeal is Structure {

    function proposeDeal(address, address, DealParameters calldata) external returns (Deal memory);
    function revertProposedDeal(address, address, uint) external view returns (Deal memory);
    function respondDeal(address, address, bool, uint) external view returns (Deal memory);
    
}