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

        // Calculate charge time
        uint chargeTime = contractInstance.calculateChargeTimeInSeconds((targetCharge - startCharge), T.cs.powerDischarge, T.ev.batteryEfficiency);

        // Calculate maximum time left in charging
        uint maxTime = contractInstance.getDeal(EVaddress, T.cpo._address).endDate - startTime;
        if ( contractInstance.getRate(T.cpo._address, T.cs.region).changeDate == 0 ) {
            uint temp = contractInstance.getNextRateChangeAtTime(startTime) - startTime;
            if ( temp < maxTime ) {
                maxTime = temp;
            }
        }
        else {
            uint temp = contractInstance.getNextRateChangeAtTime(contractInstance.getRate(T.cpo._address, T.cs.region).changeDate) - startTime;
            if ( maxTime < temp ) {
                temp = maxTime;
            }
        }

        scheme.chargeTime = chargeTime;
        scheme.maxTime = maxTime;
        scheme.region = T.cs.region;

        return generateSchemeSlots(scheme, T);
    }

    function scheduleSmartCharging(address EVaddress, address CSaddress) public returns (ChargingScheme memory) {
        require(msg.sender == contractAddress, "102");
        require(tx.origin == EVaddress || tx.origin == CSaddress, "402/302");
        require(contractInstance.isEV(EVaddress), "403");
        require(contractInstance.isCS(CSaddress), "303");
        
        CS memory cs = contractInstance.getCS(CSaddress);
                
        require(contractInstance.isDealActive(EVaddress, cs.cpo), "503");
        require(contractInstance.isConnected(EVaddress, CSaddress), "605");
        require(contractInstance.isRegionAvailable(cs.cpo, cs.region), "804");
        require(!contractInstance.isCharging(EVaddress, CSaddress), "702");

        // Transfer to new rates
        contractInstance.transferToNewRates(cs.cpo, cs.region);

        // Get smart charging spot
        return getSmartChargingSpot(EVaddress, CSaddress);
    }
    function getSmartChargingSpot(address EVaddress, address CSaddress) private returns (ChargingScheme memory) {
        // TODO : Implement

        CS memory cs = contractInstance.getCS(CSaddress);

        ChargingScheme memory scheme;

        scheme.id = getNextSchemeId();
        scheme.smartCharging = true;
        scheme.region = cs.region;
        scheme.startTime = block.timestamp + 1 weeks;

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

    function generateSchemeSlots(ChargingScheme memory scheme, Triplett memory T) private view returns (ChargingScheme memory) {
        uint chargeTimeLeft = scheme.chargeTime;
        uint startTime = scheme.startTime;
        uint elapsedTime;
        uint totalCost;
        uint index = 0;
        while ( chargeTimeLeft > 0 && elapsedTime < scheme.maxTime ) {
            
            uint currentTime = startTime + elapsedTime;

            uint currentRateIndex = contractInstance.getRateSlot(currentTime); // Current Watt Seconds rate index.
            uint currentRate = (contractInstance.getRate(T.cpo._address, T.cs.region).changeDate != 0 && currentTime >= contractInstance.getRate(T.cpo._address, T.cs.region).changeDate) 
                                ? contractInstance.getRate(T.cpo._address, T.cs.region).next[currentRateIndex]
                                : contractInstance.getRate(T.cpo._address, T.cs.region).current[currentRateIndex];
            
            uint nextRateSlot = contractInstance.getNextRateSlot(currentTime); // Unix time for when the next rate slot starts.

            bool useSlot = shouldUseSlot(currentRate, T.ev._address, T.cpo._address, T.cs.region);

            uint timeInSlot = nextRateSlot - currentTime;
            
            // Check if slot is used (Max rate limit)
            if ( useSlot ) {
                // If time in slot is bigger than charge left (needed), only charge time left is needed of slot time
                timeInSlot = timeInSlot > chargeTimeLeft
                                            ? chargeTimeLeft 
                                            : timeInSlot; 
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
        precisionTotalCost.precision = contractInstance.getRate(T.cpo._address, T.cs.region).precision;
        precisionTotalCost.value = totalCost;

        scheme.endTime = startTime + elapsedTime;
        scheme.price = precisionTotalCost;
        scheme.priceInWei = contractInstance.priceToWei(precisionTotalCost);
        scheme.slotsUsed = index;

        return scheme;
    }

    function shouldUseSlot(uint currentRate, address EVaddress, address CPOaddress, bytes3 region) private view returns (bool) {
        PrecisionNumber memory maxRate = contractInstance.getDeal(EVaddress, CPOaddress).maxRate;

        uint CPOprecision = contractInstance.getRate(CPOaddress, region).precision;
        PrecisionNumber memory slotRate = PrecisionNumber({
            value: currentRate,
            precision: CPOprecision
        });
        
        (maxRate, slotRate) = contractInstance.paddPrecisionNumber(maxRate, slotRate);

        return slotRate.value <= maxRate.value;
    }

    function getChargingSchemeFinalPrice(ChargingScheme memory scheme, uint finishTime) private view returns (uint) {       
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
        return contractInstance.priceToWei(price);
    }

}