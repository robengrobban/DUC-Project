// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';

interface IContract is Structure {

    function isRegistered(address target) external view returns (bool);
    function isCPO(address target) external view returns (bool);
    function isCS(address target) external view returns (bool);
    function isEV(address target) external view returns (bool);

    function getDeal(address EVaddress, address CPOaddress) external view returns (Deal memory);
    function isDealActive(address EVaddress, address CPOaddress) external view returns (bool);

    function isConnected(address EVaddress, address CSaddress) external view returns (bool);

    function isCharging(address EVaddress, address CSaddress) external view returns (bool);
    function isSmartCharging(address EVaddress, address CSaddress) external view returns (bool);

    function isRegionAvailable(address CPOaddress, bytes3 region) external view returns (bool);

}