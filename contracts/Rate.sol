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
        return getNextRateChangeAtTime(block.timestamp);
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