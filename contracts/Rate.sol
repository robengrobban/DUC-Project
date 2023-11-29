// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';
import './IRate.sol';
import './IContract.sol';

contract Rate is Structure, IRate {

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

    function setRates(address CPOaddress, bytes3 region, uint[RATE_SLOTS] calldata newRates, uint newRoaming, uint ratePrecision) public view returns (Rate memory) {
        require(msg.sender == contractAddress, "102");
        require(tx.origin == CPOaddress, "202");
        require(contractInstance.isCPO(CPOaddress), "203");
        require(newRates.length == RATE_SLOTS, "801");
        require(newRoaming > 0, "805");
        require(ratePrecision == PRECISION, "802");

        CPO memory cpo = contractInstance.getCPO(CPOaddress);
        require(!cpo.automaticRates, "806");

        Rate memory rate = contractInstance.getRate(CPOaddress, region);

        // Transfer current rates if it is needed
        rate = transferToNewRates(rate);

        // There are no current rates
        if ( rate.current[0] == 0 ) {
            rate.region = region;
            rate.startDate = block.timestamp;
            rate.current = newRates;
            rate.currentRoaming = newRoaming;
            rate.precision = ratePrecision;
        }
        // There are existing rates.
        else if ( rate.next[0] == 0 ) {
            if ( rate.precision != ratePrecision ) {
                revert("803");
            }
            rate.next = newRates;
            rate.nextRoaming = newRoaming;
            rate.changeDate = getNextRateChange();
        }
        else {
            revert("807");
        }

        return rate;
    }

    function nextRoaming(address CPOaddress, bytes3 region, uint newRoaming, uint roaminPrecision) public view returns (Rate memory) {
        require(msg.sender == contractAddress, "102");  
        require(tx.origin == CPOaddress, "202");
        require(contractInstance.isCPO(CPOaddress), "203");
        require(newRoaming > 0, "805");
        require(roaminPrecision == PRECISION, "802");

        CPO memory cpo = contractInstance.getCPO(CPOaddress);
        require(cpo.automaticRates, "808");

        Rate memory rate = contractInstance.getRate(CPOaddress, region);

        // Transfer current rates if it is needed
        rate = transferToNewRates(rate);
        rate.automaticNextRoaming = newRoaming;

        return rate;
    }

    function transferToNewRates(Rate memory rate) public view returns (Rate memory) {
        // TODO : Probably emit event if automatic rates apply
        if ( rate.changeDate != 0 && block.timestamp >= rate.changeDate ) {
            return transitionRate(rate);
        }
        return rate;
    }

    function getNextRateChange() public view returns (uint) {
        return getNextRateChangeAtTime(block.timestamp);
    }

    /*
    * PRIVATE FUNCTIONS
    */

    function transitionRate(Rate memory rate) private pure returns (Rate memory) {
        rate.historical = rate.current;
        rate.historicalRoaming = rate.currentRoaming;
        rate.historicalDate = rate.startDate;

        rate.current = rate.next;
        rate.currentRoaming = rate.nextRoaming;
        rate.startDate = rate.changeDate;

        uint[RATE_SLOTS] memory empty;
        rate.next = empty;
        rate.nextRoaming = 0;
        rate.changeDate = 0;

        return rate;
    }

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

}