// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';

contract Contract is Structure {
    
    /*
    * CONTRACT MANAGMENT
    */
    address owner;

    constructor () {
        owner = msg.sender;
    }

    

    /*
    * VARIABLES
    */ 
    mapping(address => CPO) CPOs;
    mapping(address => CS) CSs;
    mapping(address => EV) EVs;

    mapping(address => mapping(address => Deal)) deals; // EV -> CPO -> Deal
    uint nextDealId = 0;

    mapping(address => mapping(address => Connection)) connections; // EV -> CS -> Connection

    mapping(address => mapping(bytes3 => Rate)) rates; // CPO -> Region -> Rate

    mapping(address => mapping(address => ChargingScheme)) chargingSchemes; // EV -> CS -> CharginScheme
    uint nextSchemeId = 0;
    
    mapping(address => uint) deposits; // EV deposits

    /*
    * EVENTS
    */

    event CPORegistered(address cpo);
    event CSRegistered(address cs, address cpo);
    event EVRegistered(address ev);

    event DealProposed(address indexed ev, address indexed cpo, Deal deal);
    event DealProposalReverted(address indexed ev, address indexed cpo, Deal deal);
    event DealResponded(address indexed ev, address indexed cpo, bool accepted, Deal deal);

    event ConnectionMade(address indexed ev, address indexed cs, Connection connection);
    event Disconnection(address indexed ev, address indexed cs);

    event NewRates(address indexed cpo, bytes3 region, Rate rates);

    event ChargingRequested(address indexed ev, address indexed cs, ChargingScheme scheme);
    event InssufficientDeposit(address indexed ev, address indexed cs);
    event ChargingSchemeTimeout(address indexed ev, address indexed cs, ChargingScheme scheme);
    event ChargingAcknowledged(address indexed ev, address indexed cs, ChargingScheme scheme);
    event ChargingStopped(address indexed ev, address indexed cs, ChargingScheme scheme, uint finalPriceInWei);

    event SmartChargingScheduled(address indexed ev, address indexed cs, ChargingScheme scheme);

    /*
    * PUBLIC FUNCTIONS
    */

    function isRegistered(address target) public view returns (bool) {
        return CPOs[target].exist || CSs[target].exist || EVs[target].exist;
    }
    function isCPO(address target) public view returns (bool) {
        return CPOs[target].exist;
    }
    function isCS(address target) public view returns (bool) {
        return CSs[target].exist;
    }
    function isEV(address target) public view returns (bool) {
        return EVs[target].exist;
    }

    function registerCPO(address CPOaddress, bytes5 name) public {
        require(CPOaddress == msg.sender, "203");
        require(!isRegistered(CPOaddress), "201");
        require(name.length != 0, "204");

        CPOs[CPOaddress] = createCPO(CPOaddress, name);

        emit CPORegistered(CPOaddress);
    }

    function registerCS(address CPOaddress, address CSaddress, bytes3 region, uint powerDischarge) public {
        require(CPOaddress == msg.sender, "303");
        require(isCPO(CPOaddress), "202");
        require(!isRegistered(CSaddress), "301");
        require(powerDischarge > 0, "304");
        require(region.length != 0, "305");

        CSs[CSaddress] = createCS(CSaddress, CPOaddress, region, powerDischarge);

        emit CSRegistered(CSaddress, CPOaddress);
    }

    function registerEV(address EVaddress, uint maxCapacity, uint batteryEfficiency) public {
        require(EVaddress == msg.sender, "403");
        require(!isRegistered(EVaddress), "401");
        require(maxCapacity != 0, "404");
        require(batteryEfficiency > 0 && batteryEfficiency < 100, "405");

        EVs[EVaddress] = createEV(EVaddress, maxCapacity, batteryEfficiency);

        emit EVRegistered(EVaddress);
    }

    function proposeDeal(address EVaddress, address CPOaddress) public {
        require(EVaddress == msg.sender, "102");
        require(isEV(EVaddress), "402");
        require(isCPO(CPOaddress), "203");

        Deal memory currentDeal = deals[EVaddress][CPOaddress];
        if ( currentDeal.EV != address(0) && !currentDeal.accepted && currentDeal.endDate > block.timestamp ) {
            revert("501");
        }
        else if ( isDealActive(EVaddress, CPOaddress) ) {
            revert("502");
        }

        PrecisionNumber memory maxRate = PrecisionNumber({
            value: 500,
            precision: 1000000000
        });
        Deal memory proposedDeal = Deal({
            id: getNextDealId(),
            EV: EVaddress,
            CPO: CPOaddress,
            accepted: false,
            onlyRewneableEnergy: false,
            maxRate: maxRate,
            allowSmartCharging: true,
            startDate: block.timestamp,
            endDate: block.timestamp + 1 days
        });

        deals[EVaddress][CPOaddress] = proposedDeal;

        emit DealProposed(EVaddress, CPOaddress, proposedDeal);

    }

    function revertProposedDeal(address EVaddress, address CPOaddress, uint dealId) public {
        require(EVaddress == msg.sender, "402");
        require(isEV(EVaddress), "403");
        require(isCPO(CPOaddress), "203");

        Deal memory proposedDeal = deals[EVaddress][CPOaddress];
        if ( proposedDeal.EV == address(0) ) {
            revert("503");
        }
        else if ( proposedDeal.accepted ) {
            revert("504");
        }
        else if ( proposedDeal.id != dealId ) {
            revert("505");
        }

        removeDeal(EVaddress, CPOaddress);

        emit DealProposalReverted(EVaddress, CPOaddress, proposedDeal);

    }

    function respondDeal(address CPOaddress, address EVaddress, bool accepted, uint dealId) public {
        require(CPOaddress == msg.sender, "202");
        require(isCPO(CPOaddress), "203");
        require(isEV(EVaddress), "403");

        Deal memory proposedDeal = deals[EVaddress][CPOaddress];
        if ( proposedDeal.EV == address(0) ) {
            revert("503");
        }
        else if ( proposedDeal.accepted ) {
            revert("504");
        }
        else if ( proposedDeal.id != dealId ) {
            revert("505");
        }

        proposedDeal.accepted = accepted;

        if ( !accepted ) {
            removeDeal(EVaddress, CPOaddress);
        }
        else {
            deals[EVaddress][CPOaddress] = proposedDeal;
        }

        emit DealResponded(EVaddress, CPOaddress, accepted, proposedDeal);

    }

    function connect(address EVaddress, address CSaddress, uint nonce) public {
        require(msg.sender == EVaddress || msg.sender == CSaddress, "402/302");
        require(isEV(EVaddress), "403");
        require(isCS(CSaddress), "303");
        require(nonce != 0, "601");

        // TODO : Check if there exists a deal?

        // Check if connection exists
        Connection memory currentConnection = connections[EVaddress][CSaddress];
        if ( currentConnection.EVconnected && currentConnection.CSconnected ) {
            revert("602");
        }

        if ( msg.sender == EVaddress ) {

            // Check if connection is pending
            if ( currentConnection.nonce == nonce && currentConnection.EVconnected ) {
                revert("603");
            }

            currentConnection.nonce = nonce;
            currentConnection.EV = EVaddress;
            currentConnection.CS = CSaddress;
            currentConnection.EVconnected = true;
            
            if ( currentConnection.EVconnected && currentConnection.CSconnected ) {
                currentConnection.establishedDate = block.timestamp;
            }

            connections[EVaddress][CSaddress] = currentConnection;

            emit ConnectionMade(EVaddress, CSaddress, currentConnection);

        }
        else {

            // Check if connection is pending
            if ( currentConnection.nonce == nonce && currentConnection.CSconnected ) {
                revert("604");
            }

            currentConnection.nonce = nonce;
            currentConnection.EV = EVaddress;
            currentConnection.CS = CSaddress;
            currentConnection.CSconnected = true;

            if ( currentConnection.EVconnected && currentConnection.CSconnected ) {
                currentConnection.establishedDate = block.timestamp;
            }

            connections[EVaddress][CSaddress] = currentConnection;

            emit ConnectionMade(EVaddress, CSaddress, currentConnection);

        }

    }

    function disconnect(address EVaddress, address CSaddress) public {
        require(msg.sender == EVaddress || msg.sender == CSaddress, "402/302");
        require(isEV(EVaddress), "403");
        require(isCS(CSaddress), "303");

        // Check that there exists a connection
        Connection memory currentConnection = connections[EVaddress][CSaddress];
        if ( !(currentConnection.EVconnected && currentConnection.CSconnected ) ) {
            revert("605");
        }

        removeConnection(EVaddress, CSaddress);

        emit Disconnection(EVaddress, CSaddress);

        // Stop charging if charging is active
        if ( isCharging(EVaddress, CSaddress) ) {
            stopCharging(EVaddress, CSaddress); 
        }
    }

    function setRates(address CPOaddress, bytes3 region, uint[RATE_SLOTS] calldata newRates, uint ratePrecision) public {
        require(msg.sender == CPOaddress, "202");
        require(isCPO(CPOaddress), "203");
        require(newRates.length == RATE_SLOTS, "801");
        require(ratePrecision >= 1000000000, "802");

        // Transfer current rates if it is needed
        transferToNewRates(CPOaddress, region);

        // There are no current rates
        if ( !isRegionAvailable(CPOaddress, region) ) {
            rates[CPOaddress][region].region = region;
            rates[CPOaddress][region].startDate = block.timestamp;
            rates[CPOaddress][region].current = newRates;
            rates[CPOaddress][region].precision = ratePrecision;
        }
        // There are existing rates.
        else {
            if ( rates[CPOaddress][region].precision != ratePrecision ) {
                revert("803");
            }
            rates[CPOaddress][region].next = newRates;
            rates[CPOaddress][region].changeDate = getNextRateChange();
        }

        emit NewRates(CPOaddress, region, rates[CPOaddress][region]);

    }

    function addDeposit(address EVaddress) public payable {
        require(msg.sender == EVaddress, "402");
        deposits[EVaddress] += msg.value;
    }

    function getDeposit(address EVaddress) public view returns (uint) {
        return deposits[EVaddress];
    }

    /*function withdrawDeposit(address payable EVaddress) public {
        require(msg.sender == EVaddress, "402");
        EVaddress.transfer(deposits[EVaddress]);
        deposits[EVaddress] = 0;
    }*/

    function requestCharging(address EVaddress, address CSaddress, uint startTime, uint startCharge, uint targetCharge) payable public {
        require(msg.sender == EVaddress, "402");
        require(isEV(EVaddress), "403");
        require(isCS(CSaddress), "303");
        require(startTime >= block.timestamp, "701");

        CS memory cs = CSs[CSaddress];
                
        require(isDealActive(EVaddress, cs.cpo), "503");
        require(isConnected(EVaddress, CSaddress), "605");
        require(isRegionAvailable(cs.cpo, cs.region), "804");

        ChargingScheme memory scheme = chargingSchemes[EVaddress][CSaddress];
        require(!isCharging(EVaddress, CSaddress), "702");

        // Calculate ChargingScheme
        transferToNewRates(cs.cpo, cs.region);
        scheme = getChargingScheme(EVaddress, CSaddress, startTime, startCharge, targetCharge);

        uint moneyAvailable = msg.value + deposits[EVaddress];
        uint moneyRequired = scheme.priceInWei;

        require(moneyAvailable >= moneyRequired, "901");
        
        // Add to deposits
        deposits[EVaddress] += msg.value;
        scheme.id = getNextSchemeId();

        // Add scheme to charging struct
        scheme.EVaccepted = true;
        chargingSchemes[EVaddress][CSaddress] = scheme;

        emit ChargingRequested(EVaddress, CSaddress, scheme);
    }

    function acknowledgeCharging(address CSaddress, address EVaddress, uint schemeId) public {
        require(msg.sender == CSaddress, "302");
        require(isCS(CSaddress), "303");
        require(isEV(EVaddress), "403");
        require(schemeId > 0, "703");

        CS memory cs = CSs[CSaddress];

        require(isDealActive(EVaddress, cs.cpo), "503");
        require(isConnected(EVaddress, CSaddress), "605");

        // Get scheme
        ChargingScheme memory scheme = chargingSchemes[EVaddress][CSaddress];
        require(scheme.id == schemeId, "704");
        require(!isCharging(EVaddress, CSaddress), "702");

        if ( scheme.startTime < block.timestamp ) {
            emit ChargingSchemeTimeout(EVaddress, CSaddress, scheme);
            ChargingScheme memory blank;
            chargingSchemes[EVaddress][CSaddress] = blank;
            revert("705");
        }

        // Everything good, assume that charging will start
        scheme.CSaccepted = true;
        chargingSchemes[EVaddress][CSaddress] = scheme;

        emit ChargingAcknowledged(EVaddress, CSaddress, scheme);
    }

    function stopCharging(address EVaddress, address CSaddress) public {
        require(msg.sender == EVaddress || msg.sender == CSaddress, "402/302");
        require(isEV(EVaddress), "403");
        require(isCS(CSaddress), "303");

        Triplett memory t = getTriplett(EVaddress, CSaddress);

        // Validate that there exists a charging scheme that has not yet finished
        ChargingScheme memory scheme = chargingSchemes[EVaddress][CSaddress];
        require(isCharging(EVaddress, CSaddress), "706");

        // Clamp time to fit into scheme
        uint finishTime = block.timestamp;
        if ( finishTime >= scheme.endTime ) {
            finishTime = scheme.endTime;
        }
        else if ( finishTime < scheme.startTime ) {
            finishTime = scheme.startTime;
        }

        // Transfer money
        uint priceInWei = getChargingSchemeFinalPrice(scheme, finishTime);
        payable(t.cpo._address).transfer(priceInWei);
        deposits[EVaddress] -= priceInWei;

        // Deposits kickback
        uint remaining = deposits[EVaddress];
        payable(EVaddress).transfer(remaining);
        deposits[EVaddress] -= remaining;

        // Update scheme
        scheme.finished = true;
        scheme.finishTime = finishTime;
        scheme.finalPriceInWei = priceInWei;
        chargingSchemes[EVaddress][CSaddress] = scheme;

        // Inform about charging scheme termination
        emit ChargingStopped(EVaddress, CSaddress, scheme, priceInWei);

    }

    function getChargingScheme(address EVaddress, address CSaddress, uint startTime, uint startCharge, uint targetCharge) public view returns (ChargingScheme memory) {
        require(msg.sender == EVaddress, "402");
        require(isEV(EVaddress), "403");
        require(isCS(CSaddress), "303");
        startTime = (startTime == 0) ? block.timestamp : startTime;

        Triplett memory T = getTriplett(EVaddress, CSaddress);

        // Make sure that there is still a deal active, and that the car is not fully charged
        require(isDealActive(EVaddress, T.cpo._address), "503");
        require(startCharge < T.ev.maxCapacity && startCharge >= 0, "707");
        require(startCharge < targetCharge, "708");
        require(targetCharge <= T.ev.maxCapacity, "709");

        ChargingScheme memory scheme;
        scheme.startCharge = startCharge;
        scheme.targetCharge = targetCharge;
        scheme.startTime = startTime;

        // Calculate charge time
        uint chargeTime = calculateChargeTimeInSeconds((targetCharge - startCharge), T.cs.powerDischarge, T.ev.batteryEfficiency);

        // Calculate maximum time left in charging
        uint maxTime = deals[EVaddress][T.cpo._address].endDate - startTime;
        if ( rates[T.cpo._address][T.cs.region].changeDate == 0 ) {
            uint temp = getNextRateChangeAtTime(startTime) - startTime;
            if ( temp < maxTime ) {
                maxTime = temp;
            }
        }
        else {
            uint temp = getNextRateChangeAtTime(rates[T.cpo._address][T.cs.region].changeDate) - startTime;
            if ( maxTime < temp ) {
                temp = maxTime;
            }
        }

        scheme.chargeTime = chargeTime;
        scheme.maxTime = maxTime;
        scheme.region = T.cs.region;

        return generateSchemeSlots(scheme, T);
    }

    function scheduleSmartCharging(address EVaddress, address CSaddress) public {
        require(msg.sender == EVaddress || msg.sender == CSaddress, "402/302");
        require(isEV(EVaddress), "403");
        require(isCS(CSaddress), "303");
        
        CS memory cs = CSs[CSaddress];
                
        require(isDealActive(EVaddress, cs.cpo), "503");
        require(isConnected(EVaddress, CSaddress), "605");
        require(isRegionAvailable(cs.cpo, cs.region), "804");
        require(!isCharging(EVaddress, CSaddress), "702");

        // Transfer to new rates
        transferToNewRates(cs.cpo, cs.region);

        // Get smart charging spot
        ChargingScheme memory scheme = getSmartChargingSpot();
        // TODO : Make sure that it is a SmartCharging marked
        chargingSchemes[EVaddress][CSaddress] = scheme;

        // Emit event regarding 
        emit SmartChargingScheduled(EVaddress, CSaddress, scheme);

    }
    function getSmartChargingSpot() private view returns (ChargingScheme memory) {
        // TODO : Implement

    }

    /*function acceptSmartCharging(address EVaddress, address CSaddress, uint schemeId) public payable {
        require(msg.sender == EVaddress, "402");
        require(isCS(CSaddress), "303");
        require(isEV(EVaddress), "403");
        require(schemeId > 0, "703");

        CS memory cs = CSs[CSaddress];

        require(isDealActive(EVaddress, cs.cpo), "503");
        require(isConnected(EVaddress, CSaddress), "605");

        // Get scheme
        ChargingScheme memory scheme = chargingSchemes[EVaddress][CSaddress];
        require(scheme.id == schemeId, "704");
        require(scheme.smartCharging, "710");
        require(!isCharging(EVaddress, CSaddress), "702");

        if ( scheme.startTime < block.timestamp ) {
            emit ChargingSchemeTimeout(EVaddress, CSaddress, scheme);
            ChargingScheme memory blank;
            chargingSchemes[EVaddress][CSaddress] = blank;
            revert("705");
        }

        // Check funds
        uint moneyAvailable = msg.value + deposits[EVaddress];
        uint moneyRequired = scheme.priceInWei;

        require(moneyAvailable >= moneyRequired, "901");

        // Add to deposits
        deposits[EVaddress] += msg.value;

        // Everything good, accept the charging scheme of type smart charging
        scheme.EVaccepted = true;
        chargingSchemes[EVaddress][CSaddress] = scheme;

        emit ChargingRequested(EVaddress, CSaddress, scheme);
    }*/

    /*
    * PRIVATE FUNCTIONS
    */

    function createCPO(address CPOaddress, bytes5 name) private pure returns (CPO memory) {
        CPO memory cpo;
        cpo.exist = true;
        cpo.name = name;
        cpo._address = CPOaddress;
        return cpo;
    }

    function createCS(address CSaddress, address CPOaddress, bytes3 region, uint powerDischarge) private pure returns (CS memory) {
        CS memory cs;
        cs.exist = true;
        cs._address = CSaddress;
        cs.cpo = CPOaddress;
        cs.region = region;
        cs.powerDischarge = powerDischarge;
        return cs;    
    }

    function createEV(address EVaddress, uint maxCapacitiy, uint batteryEfficiency) private pure returns (EV memory) {
        EV memory ev;
        ev.exist = true;
        ev._address = EVaddress;
        ev.maxCapacity = maxCapacitiy;
        ev.batteryEfficiency = batteryEfficiency;
        return ev;
    }

    function getTriplett(address EVaddress, address CSaddress, address CPOaddress) private view returns (Triplett memory) {
        return Triplett({
            ev: EVs[EVaddress],
            cs: CSs[CSaddress],
            cpo: CPOs[CPOaddress]
        });
    }
    function getTriplett(address EVaddress, address CSaddress) private view returns (Triplett memory) {
        return getTriplett(EVaddress, CSaddress, CSs[CSaddress].cpo);
    }

    function getNextDealId() private returns (uint) {
        nextDealId++;
        return nextDealId;
    }

    function getNextSchemeId() private returns (uint) {
        nextSchemeId++;
        return nextSchemeId;
    }

    function isDealActive(address EVaddress, address CPOaddress) private view returns (bool) {
        return deals[EVaddress][CPOaddress].accepted && deals[EVaddress][CPOaddress].endDate > block.timestamp;
    }

    function isConnected(address EVaddress, address CSaddress) private view returns (bool) {
        return connections[EVaddress][CSaddress].EVconnected && connections[EVaddress][CSaddress].CSconnected;
    }

    function isCharging(address EVaddress, address CSaddress) private view returns (bool) {
        ChargingScheme memory scheme = chargingSchemes[EVaddress][CSaddress];
        return scheme.CSaccepted && scheme.EVaccepted && !scheme.finished;
    }
    function isSmartCharging(address EVaddress, address CSaddress) private view returns (bool) {
        ChargingScheme memory scheme = chargingSchemes[EVaddress][CSaddress];
        return scheme.smartCharging && scheme.CSaccepted && scheme.EVaccepted && !scheme.finished;
    }

    function isRegionAvailable(address CPOaddress, bytes3 region) private view returns (bool) {
        return rates[CPOaddress][region].current[0] != 0;
    }

    function removeDeal(address EVaddress, address CPOaddress) private {
        Deal memory placeholder;
        deals[EVaddress][CPOaddress] = placeholder;
    }

    function removeConnection(address EVaddress, address CPOaddress) private {
        Connection memory placeholder;
        connections[EVaddress][CPOaddress] = placeholder;
    }

    function getNextRateChange() private view returns (uint) {
        return getNextRateChangeAtTime(block.timestamp);
    }
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

    function transferToNewRates(address CPOaddress, bytes3 region) private returns (bool) {

        if ( rates[CPOaddress][region].current[0] == 0 || rates[CPOaddress][region].next[0] == 0 ) {
            return false;
        }
        if ( rates[CPOaddress][region].changeDate != 0 && block.timestamp >= rates[CPOaddress][region].changeDate ) {
            rates[CPOaddress][region].historical = rates[CPOaddress][region].current;
            rates[CPOaddress][region].historicalDate = rates[CPOaddress][region].startDate;

            rates[CPOaddress][region].current = rates[CPOaddress][region].next;
            rates[CPOaddress][region].startDate = rates[CPOaddress][region].changeDate;

            uint[RATE_SLOTS] memory empty;
            rates[CPOaddress][region].next = empty;
            rates[CPOaddress][region].changeDate = 0;

            return true;
        }
        return false;
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

    function generateSchemeSlots(ChargingScheme memory scheme, Triplett memory T) private view returns (ChargingScheme memory) {
        uint chargeTimeLeft = scheme.chargeTime;
        uint startTime = scheme.startTime;
        uint elapsedTime;
        uint totalCost;
        uint index = 0;
        while ( chargeTimeLeft > 0 && elapsedTime < scheme.maxTime ) {
            
            uint currentTime = startTime + elapsedTime;

            uint currentRateIndex = getRateSlot(currentTime); // Current Watt Seconds rate index.
            uint currentRate = (rates[T.cpo._address][T.cs.region].changeDate != 0 && currentTime >= rates[T.cpo._address][T.cs.region].changeDate) 
                                ? rates[T.cpo._address][T.cs.region].next[currentRateIndex]
                                : rates[T.cpo._address][T.cs.region].current[currentRateIndex];
            
            uint nextRateSlot = getNextRateSlot(currentTime); // Unix time for when the next rate slot starts.

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
        precisionTotalCost.precision = rates[T.cpo._address][T.cs.region].precision;
        precisionTotalCost.value = totalCost;

        scheme.endTime = startTime + elapsedTime;
        scheme.price = precisionTotalCost;
        scheme.priceInWei = priceToWei(precisionTotalCost);
        scheme.slotsUsed = index;

        return scheme;
    }

    function shouldUseSlot(uint currentRate, address EVaddress, address CPOaddress, bytes3 region) private view returns (bool) {
        PrecisionNumber memory maxRate = deals[EVaddress][CPOaddress].maxRate;

        uint CPOprecision = rates[CPOaddress][region].precision;
        PrecisionNumber memory slotRate = PrecisionNumber({
            value: currentRate,
            precision: CPOprecision
        });
        
        (maxRate, slotRate) = paddPrecisionNumber(maxRate, slotRate);

        return slotRate.value <= maxRate.value;
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

    /*
    * DEBUG FUNCTION
    */

    function debugConnection(address EVaddress, address CSaddress) public view returns (Connection memory) {
        return connections[EVaddress][CSaddress];
    }

    function debugDeal(address EVaddress, address CPOaddress) public view returns (Deal memory) {
        return deals[EVaddress][CPOaddress];
    }

    function debugEV(address EVaddress) public view returns (EV memory) {
        return EVs[EVaddress];
    }

    function debugCS(address CSaddress) public view returns (CS memory) {
        return CSs[CSaddress];
    }

    function debugCPO(address CPOaddress) public view returns (CPO memory) {
        return CPOs[CPOaddress];
    }

    function debugChargingScheme(address EVaddress, address CSaddress) public view returns (ChargingScheme memory) {
        return chargingSchemes[EVaddress][CSaddress];
    }

    function debugRates(address CPOaddress, bytes3 region) public view returns (Rate memory) {
        return rates[CPOaddress][region];
    }

}