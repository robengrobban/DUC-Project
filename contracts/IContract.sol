// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';

interface IContract is Structure {

    function isRegistered(address) external view returns (bool);
    function isCPO(address) external view returns (bool);
    function getCPO(address) external view returns (CPO memory);
    function isCS(address) external view returns (bool);
    function getCS(address) external view returns (CS memory);
    function isEV(address) external view returns (bool);
    function getEV(address) external view returns (EV memory);
    function getTriplett(address, address, address) external view returns (Triplett memory);
    //function getTriplett(address, address) external view returns (Triplett memory);

    function getDeal(address, address) external view returns (Deal memory);
    function isDealActive(address, address) external view returns (bool);

    function getConnection(address, address) external view returns (Connection memory);
    function isConnected(address, address) external view returns (bool);

    function getRate(address, bytes3) external view returns (Rate memory);
    function transferToNewRates(address, bytes3) external;
    function updateAutomaticRates() external;

    function isCharging(address, address) external view returns (bool);
    function getCharging(address, address) external view returns (ChargingScheme memory);
    function isSmartCharging(address, address) external view returns (bool);

    function isRatesAvailable(address, bytes3) external view returns (bool);
    function isRoamingAvailable(address, bytes3) external view returns (bool);

    function getDeposit(address) external view returns (uint);

}