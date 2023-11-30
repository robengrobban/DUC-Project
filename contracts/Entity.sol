// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';
import './IEntity.sol';
import './IContract.sol';

contract Entity is Structure, IEntity {

    /*
    * CONTRACT MANAGMENT
    */
    address owner;
    IContract contractInstance;
    address contractAddress;

    constructor () {
        owner = msg.sender;
    }

    function set(address _contractAddress) public {
        require(msg.sender == owner, "101");

        contractInstance = IContract(_contractAddress);
        contractAddress = _contractAddress;
    }

    /*
    * PUBLIC FUNCTIONS
    */

    function createCPO(address CPOaddress, bytes5 name, bool automaticRates) public view returns (CPO memory) {
        require(msg.sender == contractAddress, "102");
        require(CPOaddress == tx.origin, "202");
        require(!contractInstance.isRegistered(CPOaddress), "201");
        require(name.length != 0, "204");

        return CPO({
            _address: CPOaddress,
            name: name,
            automaticRates: automaticRates
        });
    }

    function createCS(address CSaddress, address CPOaddress, bytes3 region, uint powerDischarge) public view returns (CS memory) {
        require(msg.sender == contractAddress, "102");
        require(CPOaddress == tx.origin, "302");
        require(contractInstance.isCPO(CPOaddress), "202");
        require(!contractInstance.isRegistered(CSaddress), "301");
        require(region.length != 0, "305");
        require(powerDischarge > 0, "304");

        return CS({
            _address: CSaddress,
            cpo: CPOaddress,
            region: region,
            powerDischarge: powerDischarge
        });
    }

    function createEV(address EVaddress, uint maxCapacity, uint batteryEfficiency) public view returns (EV memory) {
        require(msg.sender == contractAddress, "102");
        require(EVaddress == tx.origin, "402");
        require(!contractInstance.isRegistered(EVaddress), "401");
        require(maxCapacity > 0, "404");
        require(batteryEfficiency > 0 && batteryEfficiency < 100, "405");

        return EV({
            _address: EVaddress,
            maxCapacity: maxCapacity,
            batteryEfficiency: batteryEfficiency
        });
    } 

    /*
    * PRIVATE FUNCTIONS
    */

    /*
    * LIBRARY FUNCTIONS
    */

}