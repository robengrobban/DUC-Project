// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';

interface IDeal is Structure {

    function proposeDeal(address EVaddress, address CPOaddress, uint dealId) external view returns (Deal memory);
    function verifyDealInfo(address EVaddress, address CPOaddress, uint dealId, Deal memory deal) external view;

}