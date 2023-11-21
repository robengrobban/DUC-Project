// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';
import './ICharging.sol';
import './IContract.sol';

contract Charging is Structure, ICharging {

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
    * VARIABLES
    */

    uint nextSchemeId = 0;

    /*
    * PUBLIC FUNCTIONS
    */

    function requestCharging(address EVaddress, address CSaddress, uint startTime, uint startCharge, uint targetCharge, uint deposit) public returns (ChargingScheme memory) {
        require(msg.sender == contractAddress, "102");
        require(tx.origin == EVaddress, "402");
        require(contractInstance.isEV(EVaddress), "403");
        require(contractInstance.isCS(CSaddress), "303");
        require(startTime > block.timestamp, "701");

        CS memory cs = contractInstance.getCS(CSaddress);
                
        require(contractInstance.isDealActive(EVaddress, cs.cpo), "503");
        require(contractInstance.isConnected(EVaddress, CSaddress), "605");
        require(contractInstance.isRegionAvailable(cs.cpo, cs.region), "804");
        require(!contractInstance.isCharging(EVaddress, CSaddress), "702");

        // Calculate ChargingScheme
        contractInstance.transferToNewRates(cs.cpo, cs.region);
        ChargingScheme memory scheme = getChargingScheme(EVaddress, CSaddress, startTime, startCharge, targetCharge);

        uint moneyAvailable = deposit + contractInstance.getDeposit(EVaddress);
        uint moneyRequired = scheme.priceInWei;

        require(moneyAvailable >= moneyRequired, "901");
        
        // Accept scheme
        scheme.id = getNextSchemeId();
        scheme.EVaccepted = true;

        return scheme;
    }

    function acknowledgeCharging(address CSaddress, address EVaddress, uint schemeId) public view returns (ChargingScheme memory) {
        require(msg.sender == contractAddress, "102");
        require(tx.origin == CSaddress, "302");
        require(contractInstance.isCS(CSaddress), "303");
        require(contractInstance.isEV(EVaddress), "403");
        require(schemeId > 0, "703");

        CS memory cs = contractInstance.getCS(CSaddress);

        require(contractInstance.isDealActive(EVaddress, cs.cpo), "503");
        require(contractInstance.isConnected(EVaddress, CSaddress), "605");
        
        ChargingScheme memory scheme = contractInstance.getCharging(EVaddress, CSaddress);
        require(scheme.id == schemeId, "704");
        require(!contractInstance.isCharging(EVaddress, CSaddress), "702");

        // Timeout
        if ( scheme.startTime < block.timestamp ) {
            ChargingScheme memory deleted;
            return deleted;
        }

        // Everything good, accept charging
        scheme.CSaccepted = true;
        return scheme;
    }

    function stopCharging(address EVaddress, address CSaddress) public view returns (ChargingScheme memory) {
        require(msg.sender == contractAddress, "102");
        require(tx.origin == EVaddress || tx.origin == CSaddress, "402/302");
        require(contractInstance.isEV(EVaddress), "403");
        require(contractInstance.isCS(CSaddress), "303");
        require(contractInstance.isCharging(EVaddress, CSaddress), "706");

        ChargingScheme memory scheme = contractInstance.getCharging(EVaddress, CSaddress);

        // Clamp time to fit into scheme
        uint finishTime = block.timestamp;
        if ( finishTime >= scheme.endTime ) {
            finishTime = scheme.endTime;
        }
        else if ( finishTime < scheme.startTime ) {
            finishTime = scheme.startTime;
        }

        // Calculate monetary transfer
        uint priceInWei = getChargingSchemeFinalPrice(scheme, finishTime);

        // Update scheme
        scheme.finished = true;
        scheme.finishTime = finishTime;
        scheme.finalPriceInWei = priceInWei;

        return scheme;
    }

    function getChargingScheme(address EVaddress, address CSaddress, uint startTime, uint startCharge, uint targetCharge) public view returns (ChargingScheme memory) {
        require(msg.sender == contractAddress, "102");
        require(tx.origin == EVaddress, "402");
        require(contractInstance.isEV(EVaddress), "403");
        require(contractInstance.isCS(CSaddress), "303");
        startTime = (startTime == 0) ? block.timestamp : startTime;

        Triplett memory T = contractInstance.getTriplett(EVaddress, CSaddress);

        // Make sure that there is still a deal active, and that the car is not fully charged
        require(contractInstance.isDealActive(EVaddress, T.cpo._address), "503");
        require(startCharge < T.ev.maxCapacity && startCharge >= 0, "707");
        require(startCharge < targetCharge, "708");
        require(targetCharge <= T.ev.maxCapacity, "709");

        ChargingScheme memory scheme;
        scheme.startCharge = startCharge;
        scheme.targetCharge = targetCharge;
        scheme.startTime = startTime;

        Deal memory deal = contractInstance.getDeal(T.ev._address, T.cpo._address);
        Rate memory rate = contractInstance.getRate(T.cpo._address, T.cs.region);

        // Calculate charge time 
        uint chargeTime = calculateChargeTimeInSeconds((targetCharge - startCharge), T.cs.powerDischarge, T.ev.batteryEfficiency);

        // Calculate maximum possible charging time
        uint maxTime = possibleChargingTime(deal, rate, startTime);

        scheme.chargeTime = chargeTime;
        scheme.maxTime = maxTime;
        scheme.region = T.cs.region;

        return generateSchemeSlots(scheme, deal, rate, T);
    }
    
    function scheduleSmartCharging(address EVaddress, address CSaddress, uint startCharge, uint endDate) public returns (ChargingScheme memory) {
        require(msg.sender == contractAddress, "102");
        require(tx.origin == EVaddress || tx.origin == CSaddress, "402/302");
        require(contractInstance.isEV(EVaddress), "403");
        require(contractInstance.isCS(CSaddress), "303");
        
        Triplett memory T = contractInstance.getTriplett(EVaddress, CSaddress);
                
        require(contractInstance.isDealActive(EVaddress, T.cs.cpo), "503");
        require(contractInstance.isConnected(EVaddress, CSaddress), "605");
        require(contractInstance.isRegionAvailable(T.cs.cpo, T.cs.region), "804");
        require(!contractInstance.isCharging(EVaddress, CSaddress), "702");
        require(startCharge < T.ev.maxCapacity && startCharge >= 0, "707");
        require(endDate != 0 && endDate > block.timestamp, "711");

        // Transfer to new rates
        contractInstance.transferToNewRates(T.cs.cpo, T.cs.region);

        Deal memory deal = contractInstance.getDeal(T.ev._address, T.cpo._address);
        Rate memory rate = contractInstance.getRate(T.cs.cpo, T.cs.region);

        // Get smart charging spot
        return getSmartChargingSpot(T, deal, rate, Temp(startCharge, endDate));
    }

    struct Temp {
        uint startCharge;
        uint endDate;
    }

    function getSmartChargingSpot(Triplett memory T, Deal memory deal, Rate memory rate, Temp memory temp) private returns (ChargingScheme memory) {
        // Get the charge time
        uint chargeTime = calculateChargeTimeInSeconds((T.ev.maxCapacity - temp.startCharge), T.cs.powerDischarge, T.ev.batteryEfficiency);

        // The start time for smart charging
        uint currentTime = getNextRateSlot(block.timestamp);

        // Calculate charge window based on preferences
        uint chargeWindow = temp.endDate - currentTime;
        require(chargeWindow > 0, "711");

        // The max time left for charging according to deal and rate
        uint maxTime = possibleChargingTime(deal, rate, currentTime);

        // Latset time smart charging can start to accomidate entire charge period (this does not account for preferences)
        uint latestStartTime = currentTime+maxTime-chargeTime < currentTime+chargeWindow-chargeTime
                                    ? currentTime+maxTime-chargeTime
                                    : currentTime+chargeWindow-chargeTime;

        // TODO : Max time must be influenced by latestStartTime or chargeWindow

        ChargingScheme memory scheme;
        scheme.id = getNextSchemeId();
        scheme.startCharge = temp.startCharge;
        scheme.targetCharge = T.ev.maxCapacity;
        scheme.chargeTime = chargeTime;
        scheme.startTime = currentTime;
        scheme.maxTime = maxTime;
        scheme.region = T.cs.region;
        scheme.smartCharging = true;
        scheme = generateSchemeSlots(scheme, deal, rate, T);

        while ( true ) {
            // The start time for smart charging
            currentTime += RATE_SLOT_PERIOD;
            if ( currentTime > latestStartTime ) {
                break;
            }
            maxTime = possibleChargingTime(deal, rate, currentTime);

            ChargingScheme memory suggestion;
            suggestion.id = scheme.id+1;
            suggestion.startCharge = temp.startCharge;
            suggestion.targetCharge = T.ev.maxCapacity;
            suggestion.chargeTime = chargeTime;
            suggestion.startTime = currentTime;
            suggestion.maxTime = maxTime;
            suggestion.region = T.cs.region;
            suggestion.smartCharging = true;

            suggestion = generateSchemeSlots(suggestion, deal, rate, T);

            // Should be "suggestion.priceInWei >= scheme.priceInWei" in prod
            if ( suggestion.priceInWei >= scheme.priceInWei && suggestion.activeTime >= scheme.activeTime && suggestion.idleTime <= scheme.idleTime ) {
                scheme = suggestion;
            }
            
        }

        return scheme;
    }

    function acceptSmartCharging(address EVaddress, address CSaddress, uint schemeId, uint deposit) public view returns (ChargingScheme memory) {
        require(msg.sender == contractAddress, "102");
        require(tx.origin == EVaddress, "402");
        require(contractInstance.isCS(CSaddress), "303");
        require(contractInstance.isEV(EVaddress), "403");
        require(schemeId > 0, "703");

        CS memory cs = contractInstance.getCS(CSaddress);

        require(contractInstance.isDealActive(EVaddress, cs.cpo), "503");
        require(contractInstance.isConnected(EVaddress, CSaddress), "605");

        // Get scheme
        ChargingScheme memory scheme = contractInstance.getCharging(EVaddress, CSaddress);
        require(scheme.id == schemeId, "704");
        require(scheme.smartCharging, "710");
        require(!contractInstance.isCharging(EVaddress, CSaddress), "702");

        if ( scheme.startTime < block.timestamp ) {
            ChargingScheme memory deleted;
            return deleted;
        }

        // Check funds
        uint moneyAvailable = deposit + contractInstance.getDeposit(EVaddress);
        uint moneyRequired = scheme.priceInWei;

        require(moneyAvailable >= moneyRequired, "901");

        // Smart charging accepted by EV
        scheme.EVaccepted = true;

        return scheme;
    }

    /*
    * PRIVATE FUNCTIONS
    */
    
    function getNextSchemeId() private returns (uint) {
        nextSchemeId++;
        return nextSchemeId;
    }

    function generateSchemeSlots(ChargingScheme memory scheme, Deal memory deal, Rate memory rate, Triplett memory T) private pure returns (ChargingScheme memory) {
        uint chargeTimeLeft = scheme.chargeTime;
        uint startTime = scheme.startTime;
        uint elapsedTime;
        uint totalCost;
        uint index = 0;
        while ( chargeTimeLeft > 0 && elapsedTime < scheme.maxTime ) {
            
            (bool useSlot, uint timeInSlot, uint currentRate) = loop(startTime, elapsedTime, deal, rate);
            
            // Check if slot is used (Max rate limit)
            if ( useSlot ) {
                // If time in slot is bigger than charge left (needed), only charge time left is needed of slot time
                timeInSlot = timeInSlot > chargeTimeLeft
                                            ? chargeTimeLeft 
                                            : timeInSlot; 
                scheme.activeTime += timeInSlot;
            }
            else {
                currentRate = 0;
                chargeTimeLeft += timeInSlot; // To offset the -= chargingTimeInSlot bellow, as we are not charging in this slot
                scheme.idleTime += timeInSlot;
            }

            uint slotCost = timeInSlot * currentRate * T.cs.powerDischarge;

            totalCost += slotCost;
            chargeTimeLeft -= timeInSlot;
            elapsedTime += timeInSlot; 
            
            scheme.outputCharge += T.cs.powerDischarge * timeInSlot * (useSlot ? 1 : 0);
            scheme.durations[index] = timeInSlot;
            scheme.prices[index] = slotCost;

            index++;
        }

        PrecisionNumber memory precisionTotalCost;
        precisionTotalCost.precision = rate.precision;
        precisionTotalCost.value = totalCost;

        scheme.endTime = startTime + elapsedTime;
        scheme.price = precisionTotalCost;
        scheme.priceInWei = priceToWei(precisionTotalCost);
        scheme.slotsUsed = index;

        return scheme;
    }
    function loop(uint startTime, uint elapsedTime, Deal memory deal, Rate memory rate) private pure returns (bool, uint, uint) {
        uint currentTime = startTime + elapsedTime;

        uint currentRate = (rate.changeDate != 0 && currentTime >= rate.changeDate) 
                            ? rate.next[getRateSlot(currentTime)]
                            : rate.current[getRateSlot(currentTime)];
        
        uint nextRateSlot = getNextRateSlot(currentTime); // Unix time for when the next rate slot starts.

        bool useSlot = shouldUseSlot(currentRate, deal, rate);

        uint timeInSlot = nextRateSlot - currentTime;

        return (useSlot, timeInSlot, currentRate);
    }

    function shouldUseSlot(uint currentRate, Deal memory deal, Rate memory rate) private pure returns (bool) {
        PrecisionNumber memory maxRate = deal.maxRate;

        uint CPOprecision = rate.precision;
        PrecisionNumber memory slotRate = PrecisionNumber({
            value: currentRate,
            precision: CPOprecision
        });
        
        (maxRate, slotRate) = paddPrecisionNumber(maxRate, slotRate);

        return slotRate.value <= maxRate.value;
    }

    function getChargingSchemeFinalPrice(ChargingScheme memory scheme, uint finishTime) private pure returns (uint) {       
        if ( scheme.endTime == finishTime ) {
            return scheme.priceInWei;
        }
        else if ( scheme.startTime == finishTime ) {
            return 0;
        }

        uint elapsedTime;
        PrecisionNumber memory price;
        price.precision = scheme.price.precision;

        for ( uint i = 0; i < scheme.slotsUsed; i++ ) {
           
            uint currentTime = scheme.startTime + elapsedTime;

            if ( currentTime >= finishTime ) {
                break;
            }

            uint timeInSlot = scheme.durations[i];
            timeInSlot = currentTime + timeInSlot > finishTime
                            ? timeInSlot - (currentTime + timeInSlot - finishTime)
                            : timeInSlot;

            uint slotPrice = scheme.prices[i] * timeInSlot / scheme.durations[i];
            price.value += slotPrice;
            elapsedTime += timeInSlot;

        }

        scheme.finalPrice = price;
        return priceToWei(price);
    }

    function possibleChargingTime(Deal memory deal, Rate memory rate, uint startTime) private pure returns (uint) {
        uint maxTime = deal.endDate - startTime;
        if ( rate.changeDate == 0 ) {
            uint currentRateEdge = getNextRateChangeAtTime(startTime) - startTime;
            if ( maxTime > currentRateEdge ) {
                return currentRateEdge;
            }
        }
        else {
            uint nextRateEdge = getNextRateChangeAtTime(rate.changeDate) - startTime;
            if ( maxTime > nextRateEdge ) {
                return nextRateEdge;
            }
        }
        return maxTime;
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