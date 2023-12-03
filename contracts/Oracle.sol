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
    mapping(bytes3 => uint) currentOracleDate;

    mapping(bytes3 => uint[RATE_SLOTS]) nextRates;
    mapping(bytes3 => uint) nextOracleDate;

    uint lastAutomaticRateRequest;

    /*
    * EVENTS
    */

    event RateRequest();

    /*
    * PUBLIC FUNCTIONS
    */

    function setRates(uint fetchedDate, bytes3 region, uint[RATE_SLOTS] calldata current, uint[RATE_SLOTS] calldata next) public {
        require(current.length == RATE_SLOTS && next.length == RATE_SLOTS, "1002");
        require(fetchedDate != 0 && fetchedDate <= block.timestamp, "1003");

        // Make sure rates are within current period (that fetchedDate has the same start period as currentDate)
        uint currentDate = getNextRateChangeAtTime(block.timestamp-RATE_CHANGE_IN_SECONDS);
        require(getNextRateChangeAtTime(fetchedDate-RATE_CHANGE_IN_SECONDS) == currentDate, "1003");

        // Advance rates if necessary   
        transitionRate(region, currentDate);

        // We have no oracle rates or Oracle rates are old
        if ( currentOracleDate[region] == 0 || currentOracleDate[region] < currentDate ) {
            currentOracleDate[region] = currentDate;
            currentRates[region] = current;
        }

        // Add next if next oracle date is empty and if next is not empty
        if ( nextOracleDate[region] == 0 && next[0] != 0 ) {
            nextOracleDate[region] = getNextRateChangeAtTime(block.timestamp);
            nextRates[region] = next;
        }

    }

    function automaticRate(Rate memory rate) public returns (Rate memory) {
        uint currentRateDate = getNextRateChangeAtTime(block.timestamp-RATE_CHANGE_IN_SECONDS);
        transitionRate(rate.region, currentRateDate);

        /* Oracle logic version 1
        uint rateDate = rate.startDate != 0
                                ? rate.startDate
                                : currentRateDate;
        */
        uint rateDate = rate.startDate != 0
                                ? rate.startDate
                                : currentOracleDate[rate.region];

        if ( lastAutomaticRateRequest + RATE_SLOT_PERIOD < block.timestamp ) {
            emit RateRequest();
            lastAutomaticRateRequest = block.timestamp;
        }

        return updateRate(rate, currentRates[rate.region], nextRates[rate.region], rateDate, currentOracleDate[rate.region], nextOracleDate[rate.region]);
    }

    function requestRate() public {
        emit RateRequest();
    }

    function getOracleState(bytes3 region) public view returns (uint, uint, uint[RATE_SLOTS] memory, uint[RATE_SLOTS] memory) {
        return (currentOracleDate[region], nextOracleDate[region], currentRates[region], nextRates[region]);
    }

    /*
    * PRIVATE FUNCTIONS
    */

    function transitionRate(bytes3 region, uint currentDate) private {
        if ( nextOracleDate[region] != 0 && currentDate >= nextOracleDate[region] ) {
            currentOracleDate[region] = nextOracleDate[region];
            nextOracleDate[region] = 0;
            
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