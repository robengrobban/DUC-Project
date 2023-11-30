// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';
import './IOracle.sol';
import './IRate.sol';

contract Oracle is Structure, IOracle {

    /*
    * CONTRACT MANAGMENT
    */
    address owner;
    IRate rateInstance;
    address rateAddress;

    constructor () {
        owner = msg.sender;
    }

    function set(address _rateAddress) public {
        require(msg.sender == owner, "101");

        rateInstance = IRate(_rateAddress);
        rateAddress = _rateAddress;
    }

    /*
    * VARIABLES
    */

    mapping(bytes3 => uint[RATE_SLOTS]) currentRates;
    uint currentRatesDate;

    mapping(bytes3 => uint[RATE_SLOTS]) nextRates;
    uint nextRatesDate;

    /*
    * EVENTS
    */

    event RateRequest();

    /*
    * PUBLIC FUNCTIONS
    */

    function setRates(bytes3 region, uint[RATE_SLOTS] calldata current, uint[RATE_SLOTS] calldata next) public {

        uint currentDate = getNextRateChangeAtTime(block.timestamp-RATE_CHANGE_IN_SECONDS);
        uint nextDate = getNextRateChangeAtTime(block.timestamp);

        currentRates[region] = current;
        currentRatesDate = currentDate;

        nextRates[region] = next;
        nextRatesDate = nextDate;

    }

    function automaticRate(Rate memory rate) public returns (Rate memory) {
        uint currentRateDate = getNextRateChangeAtTime(block.timestamp-RATE_CHANGE_IN_SECONDS);

        uint rateDate = rate.startDate != 0
                                ? rate.startDate
                                : currentRateDate;

        transitionRate(rate.region, currentRateDate);

        emit RateRequest();

        return updateRate(rate, currentRates[rate.region], nextRates[rate.region], rateDate, currentRatesDate, nextRatesDate);
    }

    function requestRate() public {
        emit RateRequest();
    }

    /*
    * PRIVATE FUNCTIONS
    */

    function transitionRate(bytes3 region, uint currentDate) private {
        if ( nextRatesDate != 0 && currentDate >= nextRatesDate ) {
            currentRatesDate = nextRatesDate;
            nextRatesDate = 0;
            
            currentRates[region] = nextRates[region];
            uint[RATE_SLOTS] memory empty;
            nextRates[region] = empty;
        }
    }

    function updateRate(Rate memory rate, uint[RATE_SLOTS] memory currentRate, uint[RATE_SLOTS] memory nextRate, uint rateDate, uint currentRateDate, uint nextRateDate) private pure returns (Rate memory) {
        // REVERT STATES
        if ( currentRate[0] == 0 ) {
            revert("809 (a)");
        }
        if ( currentRateDate < rateDate ) {
            revert("809 (b)");
        }

        // Init state
        if ( rate.current[0] == 0 ) {
            rate.current = currentRate;
            rate.startDate = currentRateDate;
            rate.currentRoaming = rate.automaticNextRoaming;

            rateDate = currentRateDate;
        }

        // Adjust current rate?
        if ( rateDate < currentRateDate ) {
            rate.current = currentRate;
            rate.startDate = currentRateDate;
            rate.currentRoaming = rate.automaticNextRoaming == 0
                                    ? rate.currentRoaming
                                    : rate.automaticNextRoaming;
            
            rateDate = currentRateDate;
        }

        // Add next rate?
        if ( rate.next[0] == 0 && nextRate[0] != 0 ) {
            rate.next = nextRate;
            rate.changeDate = nextRateDate;
            rate.nextRoaming = rate.automaticNextRoaming == 0
                                ? rate.currentRoaming
                                : rate.automaticNextRoaming;
        }

        return rate;
    }

    function existsRegion(bytes3 region, bytes3[] memory list) private pure returns (bool) {
        for (uint i = 0; i < list.length; i++) {
            if ( list[i] == region ) {
                return true;
            }
        }
        return false;
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