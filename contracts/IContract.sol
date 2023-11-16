// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';

interface IContract is Structure {

    function isRegistered(address) external view returns (bool);
    function isCPO(address) external view returns (bool);
    function isCS(address) external view returns (bool);
    function isEV(address) external view returns (bool);

    function getDeal(address, address) external view returns (Deal memory);
    function isDealActive(address, address) external view returns (bool);

    function isConnected(address, address) external view returns (bool);

    function isCharging(address, address) external view returns (bool);
    function isSmartCharging(address, address) external view returns (bool);

    function isRegionAvailable(address, bytes3) external view returns (bool);

}