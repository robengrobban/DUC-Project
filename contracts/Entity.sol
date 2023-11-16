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

    function set(address mainContractAddress) public {
        require(msg.sender == owner, "101");

        contractInstance = IContract(mainContractAddress);
    }

    /*
    * PUBLIC FUNCTIONS
    */

    function createCPO(address CPOaddress, bytes5 name) public view returns (CPO memory) {
        require(msg.sender == owner, "101");

        CPO memory cpo;
        cpo.exist = true;
        cpo.name = name;
        cpo._address = CPOaddress;
        return cpo;
    }

    function createCS(address CSaddress, address CPOaddress, bytes3 region, uint powerDischarge) public view returns (CS memory) {
        require(msg.sender == owner, "101");
        
        CS memory cs;
        cs.exist = true;
        cs._address = CSaddress;
        cs.cpo = CPOaddress;
        cs.region = region;
        cs.powerDischarge = powerDischarge;
        return cs;   
    }

    function createEV(address EVaddress, uint maxCapacitiy, uint batteryEfficiency) public view returns (EV memory) {
        require(msg.sender == owner, "101");
        
        EV memory ev;
        ev.exist = true;
        ev._address = EVaddress;
        ev.maxCapacity = maxCapacitiy;
        ev.batteryEfficiency = batteryEfficiency;
        return ev;
    } 

    /*
    * PRIVATE FUNCTIONS
    */

}