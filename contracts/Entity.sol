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

    function createCPO(address CPOaddress, bytes5 name) public view returns (CPO memory) {
        require(msg.sender == contractAddress, "102");
        require(CPOaddress == tx.origin, "202");
        require(!contractInstance.isRegistered(CPOaddress), "201");
        require(name.length != 0, "204");

        CPO memory cpo;
        cpo.exist = true;
        cpo.name = name;
        cpo._address = CPOaddress;
        return cpo;
    }

    function createCS(address CSaddress, address CPOaddress, bytes3 region, uint powerDischarge) public view returns (CS memory) {
        require(msg.sender == contractAddress, "102");
        require(CPOaddress == tx.origin, "302");
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
        require(msg.sender == contractAddress, "102");
        require(EVaddress == tx.origin, "402");
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

    /*
    * LIBRARY FUNCTIONS
    */

    function getNextRateChangeAtTime(uint time) private pure returns (uint) {
        uint secondsUntilRateChange = RATE_CHANGE_IN_SECONDS - (time % RATE_CHANGE_IN_SECONDS);
        return time + secondsUntilRateChange;
    }

    function getNextRateSlot(uint currentTime) private pure returns (uint) {
        uint secondsUntilRateChange = RATE_SLOT_PERIOD - (currentTime % RATE_SLOT_PERIOD);
        return currentTime + secondsUntilRateChange;
    }

    function getRateSlot(uint time) private pure returns (uint) {
        return (time / RATE_SLOT_PERIOD) % RATE_SLOTS;
    }

    function paddPrecisionNumber(PrecisionNumber memory a, PrecisionNumber memory b) private pure returns (PrecisionNumber memory, PrecisionNumber memory) {
        PrecisionNumber memory first = PrecisionNumber({value: a.value, precision: a.precision});
        PrecisionNumber memory second = PrecisionNumber({value: b.value, precision: b.precision});
        
        if ( first.precision > second.precision ) {
            uint deltaPrecision = first.precision/second.precision;
            second.value *= deltaPrecision;
            second.precision *= deltaPrecision;
        }
        else {
            uint deltaPrecision = second.precision/first.precision;
            first.value *= deltaPrecision;
            first.precision *= deltaPrecision;
        }
        return (first, second);
    }

    function calculateChargeTimeInSeconds(uint charge, uint discharge, uint efficiency) private pure returns (uint) {
        uint secondsPrecision = PRECISION * charge * 100 / (discharge * efficiency);
        // Derived from: charge / (discharge * efficienct/100)
        uint secondsRoundUp = (secondsPrecision+(PRECISION/2))/PRECISION;
        return secondsRoundUp;
    }

    function priceToWei(PrecisionNumber memory price) private pure returns (uint) {
        return ((price.value * WEI_FACTOR) + (price.precision/2)) / price.precision;
    }

}