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

    function setRates(address CPOaddress, bytes3 region, uint[RATE_SLOTS] calldata newRates, uint ratePrecision) public view returns (Rate memory) {
        require(msg.sender == contractAddress, "102");
        require(tx.origin == CPOaddress, "202");
        require(contractInstance.isCPO(CPOaddress), "203");
        require(newRates.length == RATE_SLOTS, "801");
        require(ratePrecision >= PRECISION, "802");

        Rate memory rate = contractInstance.getRate(CPOaddress, region);

        // Transfer current rates if it is needed
        rate = transferToNewRates(rate);

        // There are no current rates
        if ( rate.current[0] == 0 ) {
            rate.region = region;
            rate.startDate = block.timestamp;
            rate.current = newRates;
            rate.precision = ratePrecision;
        }
        // There are existing rates.
        else {
            if ( rate.precision != ratePrecision ) {
                revert("803");
            }
            rate.next = newRates;
            rate.changeDate = getNextRateChange();
        }

        return rate;
    }

    function transferToNewRates(Rate memory rate) public view returns (Rate memory) {
        if ( rate.changeDate != 0 && block.timestamp >= rate.changeDate ) {
            rate.historical = rate.current;
            rate.historicalDate = rate.startDate;

            rate.current = rate.next;
            rate.startDate = rate.changeDate;

            uint[RATE_SLOTS] memory empty;
            rate.next = empty;
            rate.changeDate = 0;
        }
        return rate;
    }

    function getNextRateChange() public view returns (uint) {
        return contractInstance.getNextRateChangeAtTime(block.timestamp);
    }

}