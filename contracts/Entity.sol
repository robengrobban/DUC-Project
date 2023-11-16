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

    constructor () {
        owner = msg.sender;
    }

    function set(address contractAddress) public {
        require(msg.sender == owner, "101");

        contractInstance = IContract(contractAddress);
    }

    /*
    * PUBLIC FUNCTIONS
    */

    function createCPO(address CPOaddress, bytes5 name) public view returns (CPO memory) {
        require(CPOaddress == msg.sender, "203");
        require(!contractInstance.isRegistered(CPOaddress), "201");
        require(name.length != 0, "204");

        CPO memory cpo;
        cpo.exist = true;
        cpo.name = name;
        cpo._address = CPOaddress;
        return cpo;
    }

    function createCS(address CSaddress, address CPOaddress, bytes3 region, uint powerDischarge) public view returns (CS memory) {
        require(CPOaddress == msg.sender, "303");
        require(contractInstance.isCPO(CPOaddress), "202");
        require(!contractInstance.isRegistered(CSaddress), "301");
        require(powerDischarge > 0, "304");
        require(region.length != 0, "305");

        CS memory cs;
        cs.exist = true;
        cs._address = CSaddress;
        cs.cpo = CPOaddress;
        cs.region = region;
        cs.powerDischarge = powerDischarge;
        return cs;   
    }

    function createEV(address EVaddress, uint maxCapacity, uint batteryEfficiency) public view returns (EV memory) {
        require(EVaddress == msg.sender, "403");
        require(!contractInstance.isRegistered(EVaddress), "401");
        require(maxCapacity != 0, "404");
        require(batteryEfficiency > 0 && batteryEfficiency < 100, "405");

        EV memory ev;
        ev.exist = true;
        ev._address = EVaddress;
        ev.maxCapacity = maxCapacity;
        ev.batteryEfficiency = batteryEfficiency;
        return ev;
    } 

    /*
    * PRIVATE FUNCTIONS
    */

}