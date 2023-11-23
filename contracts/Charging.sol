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

    function requestCharging(address EVaddress, address CSaddress, address CPOaddress, uint startTime, uint startCharge, uint targetCharge, uint deposit) public returns (ChargingScheme memory) {
        require(msg.sender == contractAddress, "102");
        require(tx.origin == EVaddress, "402");
        require(contractInstance.isEV(EVaddress), "403");
        require(contractInstance.isCS(CSaddress), "303");
        require(contractInstance.isCPO(CPOaddress), "203");
        require(startTime > block.timestamp, "701");

        //Triplett memory T = contractInstance.getTriplett(EVaddress, CSaddress, CPOaddress);
        CS memory cs = contractInstance.getCS(CSaddress);
                
        require(contractInstance.isDealActive(EVaddress, CPOaddress), "503");
        require(contractInstance.isConnected(EVaddress, CSaddress), "605");
        require(contractInstance.isRatesAvailable(CPOaddress, cs.region), "804");
        require(!contractInstance.isCharging(EVaddress, CSaddress), "702");

        if ( CPOaddress != cs.cpo ) {
            // Roaming applies
            require(contractInstance.isRoamingAvailable(cs.cpo, cs.region), "712");
            contractInstance.transferToNewRates(cs.cpo, cs.region); // Update roaming rates if necessary
        }
        contractInstance.transferToNewRates(CPOaddress, cs.region);

        // Calculate ChargingScheme
        ChargingScheme memory scheme = getChargingScheme(EVaddress, CSaddress, CPOaddress, startTime, startCharge, targetCharge);

        uint moneyAvailable = deposit + contractInstance.getDeposit(EVaddress);
        uint moneyRequired = scheme.priceInWei + scheme.roamingPriceInWei;

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
        require(contractInstance.isConnected(EVaddress, CSaddress), "605");
        
        ChargingScheme memory scheme = contractInstance.getCharging(EVaddress, CSaddress);
        require(contractInstance.isDealActive(EVaddress, scheme.CPOaddress), "503");
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
        (uint priceInWei, uint roamingPriceInWei) = getChargingSchemeFinalPrice(scheme, finishTime);

        // Update scheme
        scheme.finished = true;
        scheme.finishTime = finishTime;
        scheme.finalPriceInWei = priceInWei;
        scheme.finalRoamingPriceInWei = roamingPriceInWei;

        return scheme;
    }

    function getChargingScheme(address EVaddress, address CSaddress, address CPOaddress, uint startTime, uint startCharge, uint targetCharge) public view returns (ChargingScheme memory) {
        require(msg.sender == contractAddress, "102");
        require(tx.origin == EVaddress, "402");
        require(contractInstance.isEV(EVaddress), "403");
        require(contractInstance.isCS(CSaddress), "303");
        require(contractInstance.isCPO(CPOaddress), "203");
        startTime = (startTime == 0) ? block.timestamp : startTime;

        Triplett memory T = contractInstance.getTriplett(EVaddress, CSaddress, CPOaddress);

        // Make sure that there is still a deal active, and that the car is not fully charged
        // TODO : remove some of the require that happened requestCharging?
        require(contractInstance.isDealActive(EVaddress, CPOaddress), "503");
        require(startCharge < T.ev.maxCapacity && startCharge >= 0, "707");
        require(startCharge < targetCharge, "708");
        require(targetCharge <= T.ev.maxCapacity, "709");

        ChargingScheme memory scheme;
        scheme.startCharge = startCharge;
        scheme.targetCharge = targetCharge;
        scheme.startTime = startTime;
        scheme.CPOaddress = CPOaddress;

        Chargelett memory C;
        // Check if roaming
        if ( CPOaddress != T.cs.cpo ) {
            scheme.roaming = true;
            C.roaming = contractInstance.getRate(T.cs.cpo, T.cs.region);
        }

        C.deal = contractInstance.getDeal(EVaddress, CPOaddress);
        C.rate = contractInstance.getRate(CPOaddress, T.cs.region);

        // Calculate charge time 
        uint chargeTime = calculateChargeTimeInSeconds((targetCharge - startCharge), T.cs.powerDischarge, T.ev.batteryEfficiency);

        // Calculate maximum possible charging time
        uint maxTime = possibleChargingTime(C.deal, C.rate, startTime);

        scheme.chargeTime = chargeTime;
        scheme.maxTime = maxTime;
        scheme.region = T.cs.region;

        return generateSchemeSlots(scheme, C, T);
    }
    
    // TODO : Smart charging only if deal allows
    function scheduleSmartCharging(address EVaddress, address CSaddress, address CPOaddress, uint startCharge, uint endDate) public returns (ChargingScheme memory) {
        require(msg.sender == contractAddress, "102");
        require(tx.origin == EVaddress || tx.origin == CSaddress, "402/302");
        require(contractInstance.isEV(EVaddress), "403");
        require(contractInstance.isCS(CSaddress), "303");
        require(contractInstance.isCPO(CPOaddress), "203");
        
        Triplett memory T = contractInstance.getTriplett(EVaddress, CSaddress, CPOaddress);
                
        require(contractInstance.isDealActive(EVaddress, CPOaddress), "503");
        require(contractInstance.isConnected(EVaddress, CSaddress), "605");
        require(contractInstance.isRatesAvailable(CPOaddress, T.cs.region), "804");
        require(!contractInstance.isCharging(EVaddress, CSaddress), "702");
        require(startCharge < T.ev.maxCapacity && startCharge >= 0, "707");
        require(endDate != 0 && endDate > block.timestamp, "711");

        // Check roaming
        Chargelett memory C;
        if ( CPOaddress != T.cs.cpo ) {
            require(contractInstance.isRoamingAvailable(T.cs.cpo, T.cs.region), "712");
            contractInstance.transferToNewRates(T.cs.cpo, T.cs.region); // Update roaming rates if necessary
            C.roaming = contractInstance.getRate(T.cs.cpo, T.cs.region);
        }

        // Transfer to new rates
        contractInstance.transferToNewRates(CPOaddress, T.cs.region);

        C.deal = contractInstance.getDeal(EVaddress, CPOaddress);
        C.rate = contractInstance.getRate(CPOaddress, T.cs.region);

        // Get smart charging spot
        return getSmartChargingSpot(T, C, startCharge, endDate);
    }

    function getSmartChargingSpot(Triplett memory T, Chargelett memory C, uint startCharge, uint endDate) private returns (ChargingScheme memory) {
        // Get the charge time
        uint chargeTime = calculateChargeTimeInSeconds((T.ev.maxCapacity - startCharge), T.cs.powerDischarge, T.ev.batteryEfficiency);

        // The start time for smart charging
        uint currentDate = getNextRateSlot(block.timestamp + 30 seconds);

        // Calculate charge window based on preferences
        require(endDate >= currentDate, "711");
        uint chargeWindow = endDate - currentDate;

        // The max time left for charging according to deal and rate
        uint maxTime = possibleChargingTime(C.deal, C.rate, currentDate);

        // Charge window needs to be within bounds of maximum possible charging time
        chargeWindow = chargeWindow < maxTime
                        ? chargeWindow
                        : maxTime;

        // Latset time smart charging can start to accomidate entire charge period (this does not account for preferences)
        uint latestStartDate = currentDate + chargeWindow - chargeTime;

        // Adjust max time, so that it does not go above latest start date
        maxTime = chargeWindow;

        ChargingScheme memory scheme;
        scheme.id = getNextSchemeId();
        scheme.CPOaddress = T.cpo._address;
        scheme.startCharge = startCharge;
        scheme.targetCharge = T.ev.maxCapacity;
        scheme.chargeTime = chargeTime;
        scheme.startTime = currentDate;
        scheme.maxTime = maxTime;
        scheme.region = T.cs.region;
        scheme.smartCharging = true;
        scheme.roaming = (C.roaming.currentRoaming != 0);
        scheme = generateSchemeSlots(scheme, C, T);

        while ( true ) {
            // The start time for smart charging
            currentDate += RATE_SLOT_PERIOD;
            if ( currentDate > latestStartDate ) {
                break;
            }
            chargeWindow -= RATE_SLOT_PERIOD;
            maxTime = chargeWindow;

            ChargingScheme memory suggestion;
            suggestion.id = scheme.id;
            suggestion.CPOaddress = scheme.CPOaddress;
            suggestion.startCharge = startCharge;
            suggestion.targetCharge = T.ev.maxCapacity;
            suggestion.chargeTime = chargeTime;
            suggestion.startTime = currentDate;
            suggestion.maxTime = maxTime;
            suggestion.region = T.cs.region;
            suggestion.smartCharging = scheme.smartCharging;
            suggestion.roaming = scheme.roaming;

            suggestion = generateSchemeSlots(suggestion, C, T);

            if ( (suggestion.priceInWei > scheme.priceInWei && suggestion.activeTime >= scheme.activeTime) || (suggestion.activeTime > scheme.activeTime) ) {
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
        require(contractInstance.isConnected(EVaddress, CSaddress), "605");
        require(schemeId > 0, "703");

        // Get scheme
        ChargingScheme memory scheme = contractInstance.getCharging(EVaddress, CSaddress);
        require(contractInstance.isDealActive(EVaddress, scheme.CPOaddress), "503");
        require(scheme.id == schemeId, "704");
        require(scheme.smartCharging, "710");
        require(!contractInstance.isCharging(EVaddress, CSaddress), "702");

        if ( scheme.startTime < block.timestamp ) {
            ChargingScheme memory deleted;
            return deleted;
        }

        // Check funds
        uint moneyAvailable = deposit + contractInstance.getDeposit(EVaddress);
        uint moneyRequired = scheme.priceInWei + scheme.roamingPriceInWei;

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

    function generateSchemeSlots(ChargingScheme memory scheme, Chargelett memory C, Triplett memory T) private pure returns (ChargingScheme memory) {
        uint chargeTimeLeft = scheme.chargeTime;
        uint startTime = scheme.startTime;
        uint elapsedTime;
        scheme.price.precision = PRECISION;
        scheme.roamingPrice.precision = PRECISION;
        uint index = 0;
        while ( chargeTimeLeft > 0 && elapsedTime < scheme.maxTime ) {
            
            (bool useSlot, uint timeInSlot, uint currentRate) = slotDetails(startTime, elapsedTime, C.deal, C.rate);

            // If time in slot is bigger than max time allowed, cap to max time
            timeInSlot = elapsedTime+timeInSlot > scheme.maxTime
                            ? scheme.maxTime - elapsedTime
                            : timeInSlot;

            // Check if slot is used (Max rate limit)
            if ( useSlot ) {
                // If time in slot is bigger than charge left (needed), only charge time left is needed of slot time
                timeInSlot = timeInSlot > chargeTimeLeft
                            ? chargeTimeLeft 
                            : timeInSlot; 

                chargeTimeLeft -= timeInSlot;
                elapsedTime += timeInSlot; 

                scheme.activeTime += timeInSlot;
                scheme.outputCharge += T.cs.powerDischarge * timeInSlot;
                scheme.prices[index] = timeInSlot * currentRate * T.cs.powerDischarge;
                scheme.roamingFees[index] = timeInSlot * C.roaming.currentRoaming * T.cs.powerDischarge;

                scheme.price.value += scheme.prices[index];
                scheme.roamingPrice.value += scheme.roamingFees[index];
            }
            else {
                elapsedTime += timeInSlot; 
                scheme.idleTime += timeInSlot;
            }

            scheme.durations[index] = timeInSlot;
            
            index++;
        }

        scheme.priceInWei = priceToWei(scheme.price);
        scheme.roamingPriceInWei = priceToWei(scheme.roamingPrice);
        
        scheme.endTime = startTime + elapsedTime;
        scheme.slotsUsed = index;

        return scheme;
    }
    function slotDetails(uint startTime, uint elapsedTime, Deal memory deal, Rate memory rate) private pure returns (bool, uint, uint) {
        uint currentTime = startTime + elapsedTime;

        uint currentRate = (rate.changeDate != 0 && currentTime >= rate.changeDate) 
                            ? rate.next[getRateSlot(currentTime)]
                            : rate.current[getRateSlot(currentTime)];
        
        uint nextRateSlot = getNextRateSlot(currentTime); // Unix time for when the next rate slot starts.

        bool useSlot = currentRate <= deal.maxRate.value;

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

    function getChargingSchemeFinalPrice(ChargingScheme memory scheme, uint finishTime) private pure returns (uint, uint) {
        if ( scheme.endTime == finishTime ) {
            return (scheme.priceInWei, scheme.roamingPriceInWei);
        }
        else if ( scheme.startTime == finishTime ) {
            return (0, 0);
        }

        uint elapsedTime;
        scheme.finalPrice.precision = PRECISION;
        scheme.finalRoamingPrice.precision = PRECISION;

        for ( uint i = 0; i < scheme.slotsUsed; i++ ) {
           
            uint currentTime = scheme.startTime + elapsedTime;

            if ( currentTime >= finishTime ) {
                break;
            }

            uint timeInSlot = scheme.durations[i];
            timeInSlot = currentTime + timeInSlot > finishTime
                            ? timeInSlot - (currentTime + timeInSlot - finishTime)
                            : timeInSlot;

            scheme.finalPrice.value += (scheme.prices[i] * timeInSlot) / scheme.durations[i];
            scheme.finalRoamingPrice.value += (scheme.roamingFees[i] * timeInSlot) / scheme.durations[i];
            elapsedTime += timeInSlot;

        }

        return (priceToWei(scheme.finalPrice), priceToWei(scheme.finalRoamingPrice));
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