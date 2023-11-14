// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

contract Contract {
    
    /*
    * VARIABLES
    */

    uint constant RATE_SLOTS = 60;                  // How many rate slots there are, should be compatible with how often the rate changes.

    uint constant RATE_CHANGE_IN_SECONDS = 3600;    // What is the factor of rate changes in seconds? 
                                                    // Used to calculate when a new rate starts, see function getNextRateChange()
                                                    // 60 = rate change every minute
                                                    // 3600 = rate change every hour (60 * 60)
                                                    // 86400 = rate change every day (60 * 60 * 24)

    uint constant RATE_SLOT_PERIOD = RATE_CHANGE_IN_SECONDS / RATE_SLOTS;   // This gives how many seconds are in one rate slot period
                                                                            // If rate changes every hour, and have a new price every minute
                                                                            // That means that there are 60 seconds to account for in each 
                                                                            // rate charging period.
                                                                            // If hourly rate are user -> 86400 / 24 = 3600, there are so many seconds
                                                                            // in one hour, which is one charging period.
                                                                            // This is important as prices are related to this, so RATE_CHARGE_PERIOD
                                                                            // are the amount of seconds that needs to pass in order for the full charge
                                                                            // rate price to be accounted for. 

    uint constant WEI_FACTOR = 100;     // This says that the price to pay is per 100 WEI. Meaning, if the price gets calculated to 4.3, it would mean
                                        // that 430 WEI is the price. Higher value will grant higher precision, but this works fine for testing.

    uint constant PRECISION = 1000000000;           // Affects the precision on calculation, as they are all integer calulcations.
    struct PrecisionNumber {
        uint value;
        uint precision;
    }

    mapping(address => CPO) CPOs;
    mapping(address => CS) CSs;
    mapping(address => EV) EVs;

    struct CPO {
        bool exist;
        bytes5 name;
        address _address;
        bool useNordPoolRates;
        Rate rate; // TODO : Rates must be subject to region, such as SE1,SE2,SE3,SE4
    }
    struct Rate {
        bytes3 region;

        uint[RATE_SLOTS] current; // Rate in Watt seconds
        uint startDate; // The date when the rates was applied
        uint precision; // The selected precision for Rates. (INT calculation)

        uint[RATE_SLOTS] next; // The next scheduled rates
        uint changeDate; // The date when the new rates are expected to change

        uint[RATE_SLOTS] historical; // What the last rate was
        uint historicalDate; // When the rates in historical started
    }
    struct CS {
        bool exist;
        address _address;
        uint powerDischarge; // Watt output
        address cpo; // Connection to what CPO
    }
    struct EV {
        bool exist;
        address _address;
        uint maxCapacity; // Watt Seconds of max charge
        uint batteryEfficiency; // Battery charge efficency (0-100)
    }

    mapping(address => mapping(address => Deal)) deals; // EV -> CPO -> Deal
    uint nextDealId = 0;
    struct Deal {
        uint id;
        bool accepted;
        address EV;
        address CPO;
        uint startDate;
        uint endDate;
        bool onlyRewneableEnergy;
        PrecisionNumber maxRate;
        bool allowSmartCharging;
    }

    mapping(address => mapping(address => Connection)) connections; // EV -> CS -> Connection
    struct Connection {
        uint nonce;
        address EV;
        address CS;
        bool EVconnected;
        bool CSconnected;
        uint establishedDate;
    }

    mapping(address => mapping(address => ChargingScheme)) chargingSchemes; // EV -> CS -> CharginScheme
    uint nextSchemeId = 0;
    struct ChargingScheme {
        uint id;
        bool EVaccepted;
        bool CSaccepted;
        bool finished;
        bool smartCharging;
        uint targetCharge;
        uint startCharge;
        uint startTime;
        uint chargeTime;
        uint idleTime;
        uint maxTime;
        uint endTime;
        uint finishTime;
        PrecisionNumber price;
        uint priceInWei;
        uint finalPriceInWei;
        uint slotsUsed;
        uint[RATE_SLOTS*2] durations;
        uint[RATE_SLOTS*2] prices;
    }

    mapping(address => uint) deposits; // EV deposits

    /*
    * Helper structs
    */
    struct Triplett {
        EV ev;
        CS cs;
        CPO cpo;
    }

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

    event NewRates(address indexed cpo, CPO details);

    event ChargingRequested(address indexed ev, address indexed cs, ChargingScheme scheme);
    event InssufficientDeposit(address indexed ev, address indexed cs);
    event ChargingSchemeTimeout(address indexed ev, address indexed cs, ChargingScheme scheme);
    event ChargingAcknowledged(address indexed ev, address indexed cs, ChargingScheme scheme);
    event ChargingStopped(address indexed ev, address indexed cs, ChargingScheme scheme, uint finalPriceInWei);

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

    function registerCS(address CPOaddress, address CSaddress, uint powerDischarge) public {
        require(CPOaddress == msg.sender, "303");
        require(isCPO(CPOaddress), "202");
        require(!isRegistered(CSaddress), "301");
        require(powerDischarge > 0, "304");

        CSs[CSaddress] = createCS(CSaddress, CPOaddress, powerDischarge);

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

    function setRates(address CPOaddress, uint[RATE_SLOTS] calldata rates, uint ratePrecision) public {
        require(msg.sender == CPOaddress, "202");
        require(isCPO(CPOaddress), "203");
        require(rates.length == RATE_SLOTS, "801");
        require(ratePrecision >= 1000000000, "802");

        // Transfer current rates if it is needed
        transferToNewRates(CPOaddress);

        CPO memory cpo = CPOs[CPOaddress];
        // There are no current rates
        if ( cpo.rate.current[0] == 0 ) {
            cpo.rate.startDate = block.timestamp;
            cpo.rate.current = rates;
            cpo.rate.precision = ratePrecision;
        }
        // There are existing rates.
        else {
            if ( cpo.rate.precision != ratePrecision ) {
                revert("803");
            }
            cpo.rate.next = rates;
            cpo.rate.changeDate = getNextRateChange();
        }

        CPOs[CPOaddress] = cpo;

        emit NewRates(CPOaddress, cpo);

    }

    function addDeposit(address EVaddress) public payable {
        require(msg.sender == EVaddress, "402");
        deposits[EVaddress] += msg.value;
    }

    function getDeposit(address EVaddress) public view returns (uint) {
        return deposits[EVaddress];
    }

    /*function withdrawDeposit(address payable EVaddress) public {
        require(msg.sender == EVaddress, "Sender must be EV address.");
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

        ChargingScheme memory scheme = chargingSchemes[EVaddress][CSaddress];
        require(!isCharging(EVaddress, CSaddress), "702");

        // Calculate ChargingScheme
        transferToNewRates(cs.cpo);
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

        return priceToWei(price);

    }

    /*function estimateChargingPrice(address EVaddress, address CSaddress, uint startTime, uint startCharge) public view returns (PrecisionNumber memory) {
        require(msg.sender == EVaddress, "Sender must be EV address");
        require(isEV(EVaddress), "EV address must be registered EV");
        require(isCS(CSaddress), "CS address must be registered CS");
        startTime = (startTime == 0) ? block.timestamp : startTime;

        EV memory ev = EVs[EVaddress];
        CS memory cs = CSs[CSaddress];
        CPO memory cpo = CPOs[cs.cpo];

        // Make sure that there is still a deal active, and that the car is not fully charged
        require(isDealActive(EVaddress, cs.cpo), "There is no deal between EV and CS CPO");
        require(startCharge < ev.maxCapacity && startCharge >= 0, "Current Charge cannot be negative, and must be less than max capacity");

        // Calculate charge time, and adjust it if the deal ends before fully charged.
        uint chargeTime = calculateChargeTimeInSeconds((ev.maxCapacity - startCharge), cs.powerDischarge, ev.batteryEfficiency);
        uint timeLeft = deals[EVaddress][cs.cpo].endDate - startTime;
        chargeTime = (chargeTime > timeLeft) 
                                ? timeLeft 
                                : chargeTime;

        // Adjust if there is a upper time limit on rates
        if ( cpo.rate.changeDate == 0 ) {
            timeLeft = getNextRateChangeAtTime(startTime)-startTime;
        }
        else {
            timeLeft = getNextRateChangeAtTime(cpo.rate.changeDate)-startTime;
        }
        chargeTime = (chargeTime > timeLeft)
                                ? timeLeft
                                : chargeTime;

        uint elapsedTime;
        uint totalCost;
        while ( chargeTime > 0 ) {
            
            uint currentTime = startTime + elapsedTime;

            uint currentRateIndex = getRateSlot(currentTime); // Current Watt Seconds rate index.
            uint currentRate = (cpo.rate.changeDate != 0 && currentTime >= cpo.rate.changeDate) 
                                ? cpo.rate.next[currentRateIndex]
                                : cpo.rate.current[currentRateIndex];
            
            uint nextRateSlot = getNextRateSlot(currentTime); // Unix time for when the next rate starts.

            uint chargingTimeInSlot = (nextRateSlot - currentTime) < chargeTime
                                            ? (nextRateSlot - currentTime) 
                                            : chargeTime; // Seconds in this rate period.

            totalCost += chargingTimeInSlot * currentRate * cs.powerDischarge;
            chargeTime -= chargingTimeInSlot;
            elapsedTime += chargingTimeInSlot;

        }

        PrecisionNumber memory precisionTotalCost;
        precisionTotalCost.precision = cpo.rate.precision;
        precisionTotalCost.value = totalCost;
        return precisionTotalCost;
    }*/

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
        if ( T.cpo.rate.changeDate == 0 ) {
            uint temp = getNextRateChangeAtTime(startTime) - startTime;
            if ( temp < maxTime ) {
                maxTime = temp;
            }
        }
        else {
            uint temp = getNextRateChangeAtTime(T.cpo.rate.changeDate) - startTime;
            if ( maxTime < temp ) {
                temp = maxTime;
            }
        }

        scheme.chargeTime = chargeTime;
        scheme.maxTime = maxTime;

        return generateSchemeSlots(scheme, T);
    }

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

    function createCS(address CSaddress, address CPOaddress, uint powerDischarge) private pure returns (CS memory) {
        CS memory cs;
        cs.exist = true;
        cs._address = CSaddress;
        cs.cpo = CPOaddress;
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
        //return ((scheme.accepted || scheme.finished) && !(scheme.accepted && scheme.finished));
        //return chargingSchemes[EVaddress][CSaddress].accepted && !chargingSchemes[EVaddress][CSaddress].finished;
    }
    function isSmartCharging(address EVaddress, address CSaddress) private view returns (bool) {
        ChargingScheme memory scheme = chargingSchemes[EVaddress][CSaddress];
        return scheme.smartCharging && scheme.CSaccepted && scheme.EVaccepted && !scheme.finished;
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

    function transferToNewRates(address CPOaddress) private returns (bool) {

        CPO memory cpo = CPOs[CPOaddress];

        if ( cpo.rate.current[0] == 0 || cpo.rate.next[0] == 0 ) {
            return false;
        }
        if ( cpo.rate.changeDate != 0 && block.timestamp >= cpo.rate.changeDate ) {
            cpo.rate.historical = cpo.rate.current;
            cpo.rate.historicalDate = cpo.rate.startDate;

            cpo.rate.current = cpo.rate.next;
            cpo.rate.startDate = cpo.rate.changeDate;

            uint[60] memory empty;
            cpo.rate.next = empty;
            cpo.rate.changeDate = 0;

            CPOs[CPOaddress] = cpo;

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

    function generateSchemeSlots(ChargingScheme memory scheme, Triplett memory triplett) private view returns (ChargingScheme memory) {
        uint chargeTimeLeft = scheme.chargeTime;
        uint startTime = scheme.startTime;
        uint elapsedTime;
        uint totalCost;
        uint index = 0;
        while ( chargeTimeLeft > 0 && elapsedTime < scheme.maxTime ) {
            
            uint currentTime = startTime + elapsedTime;

            uint currentRateIndex = getRateSlot(currentTime); // Current Watt Seconds rate index.
            uint currentRate = (triplett.cpo.rate.changeDate != 0 && currentTime >= triplett.cpo.rate.changeDate) 
                                ? triplett.cpo.rate.next[currentRateIndex]
                                : triplett.cpo.rate.current[currentRateIndex];
            
            uint nextRateSlot = getNextRateSlot(currentTime); // Unix time for when the next rate slot starts.

            bool useSlot = shouldUseSlot(currentRate, triplett.ev._address, triplett.cpo._address);

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

            uint slotCost = timeInSlot * currentRate * triplett.cs.powerDischarge;

            totalCost += slotCost;
            chargeTimeLeft -= timeInSlot;
            elapsedTime += timeInSlot; 

            scheme.durations[index] = timeInSlot;
            scheme.prices[index] = slotCost;

            index++;
        }

        PrecisionNumber memory precisionTotalCost;
        precisionTotalCost.precision = triplett.cpo.rate.precision;
        precisionTotalCost.value = totalCost;

        scheme.endTime = startTime + elapsedTime;
        scheme.price = precisionTotalCost;
        scheme.priceInWei = priceToWei(precisionTotalCost);
        scheme.slotsUsed = index;

        return scheme;
    }

    function shouldUseSlot(uint currentRate, address EVaddress, address CPOaddress) private view returns (bool) {
        PrecisionNumber memory maxRate = deals[EVaddress][CPOaddress].maxRate;

        uint CPOprecision = CPOs[CPOaddress].rate.precision;
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

}