// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';

interface ICharging is Structure {

    function requestCharging(address, address, uint, uint, uint, uint) external returns (ChargingScheme memory);
    function acknowledgeCharging(address, address, uint) external view returns (ChargingScheme memory);
    function stopCharging(address, address) external view returns (ChargingScheme memory);

    function getChargingScheme(address, address, uint, uint, uint) external view returns (ChargingScheme memory);

    function scheduleSmartCharging(address, address, uint) external returns (ChargingScheme memory);
    function acceptSmartCharging(address, address, uint, uint) external view returns (ChargingScheme memory);
    
}