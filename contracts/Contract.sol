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
        address _address;
        Rate rate;
    }
    struct Rate {
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

    // Charging here

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

    event RegisteredCPO(address cpo);
    event RegisteredCS(address cs, address cpo);
    event RegisteredEV(address ev);

    event ProposedDeal(address indexed ev, address indexed cpo, Deal deal);
    event RevertProposedDeal(address indexed ev, address indexed cpo, Deal deal);
    event RespondDeal(address indexed ev, address indexed cpo, bool accepted, Deal deal);

    event ConnectionMade(address indexed ev, address indexed cs, Connection connection);
    event Disconnection(address indexed ev, address indexed cs);

    event NewRates(address indexed cpo, CPO details);

    event RequestCharging(address indexed ev, address indexed cs, uint startTime, uint startCharge);
    event InssufficientDeposit(address indexed ev, address indexed cs);
    event StartCharging(address indexed ev, address indexed cs, ChargingScheme scheme);
    event StopCharging(address indexed ev, address indexed cs);

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

    function registerCPO(address CPOaddress) public {
        require(CPOaddress == msg.sender, "Sender address must be the same as register address");
        require(!isRegistered(CPOaddress), "CPO already registered");

        CPOs[CPOaddress] = createCPO(CPOaddress);

        emit RegisteredCPO(CPOaddress);
    }

    function registerCS(address CPOaddress, address CSaddress, uint powerDischarge) public {
        require(CPOaddress == msg.sender, "Sender address must be the same as register address");
        require(isCPO(CPOaddress), "Sender is not a CPO");
        require(!isRegistered(CSaddress), "CS already registered");
        require(powerDischarge > 0, "Power discharg must be greater than 0");

        CSs[CSaddress] = createCS(CSaddress, CPOaddress, powerDischarge);

        emit RegisteredCS(CSaddress, CPOaddress);
    }

    function registerEV(address EVaddress, uint maxCapacity, uint batteryEfficiency) public {
        require(EVaddress == msg.sender, "Sender address must be the same as register address");
        require(!isRegistered(EVaddress), "EV already registered");
        require(maxCapacity != 0, "Max battery capacity cannot be set to 0");
        require(batteryEfficiency > 0 && batteryEfficiency < 100, "Battery efficiency must be between 0 and 100, but not be 0 or 100");

        EVs[EVaddress] = createEV(EVaddress, maxCapacity, batteryEfficiency);

        emit RegisteredEV(EVaddress);
    }

    function proposeDeal(address EVaddress, address CPOaddress) public {
        require(EVaddress == msg.sender, "Sender address must be the same as EV address");
        require(isEV(EVaddress), "EV address not registered EV");
        require(isCPO(CPOaddress), "CPO address not registered CPO");

        Deal memory currentDeal = deals[EVaddress][CPOaddress];
        if ( currentDeal.EV != address(0) && !currentDeal.accepted && currentDeal.endDate > block.timestamp ) {
            revert("Deal already proposed, waiting response");
        }
        else if ( isDealActive(EVaddress, CPOaddress) ) {
            revert("Accepted deal already exists");
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

        emit ProposedDeal(EVaddress, CPOaddress, proposedDeal);

    }

    function revertProposedDeal(address EVaddress, address CPOaddress, uint dealId) public {
        require(EVaddress == msg.sender, "Sender address must be the same as EV address");
        require(isEV(EVaddress), "EV address not registered EV");
        require(isCPO(CPOaddress), "CPO address not registered CPO");

        Deal memory proposedDeal = deals[EVaddress][CPOaddress];
        if ( proposedDeal.EV == address(0) ) {
            revert("Deal does not exist");
        }
        else if ( proposedDeal.accepted ) {
            revert("Deal already accepted");
        }
        else if ( proposedDeal.id != dealId ) {
            revert("Wrong deal ID, proposed deal might have changed");
        }

        removeDeal(EVaddress, CPOaddress);

        emit RevertProposedDeal(EVaddress, CPOaddress, proposedDeal);

    }

    function respondDeal(address CPOaddress, address EVaddress, bool accepted, uint dealId) public {
        require(CPOaddress == msg.sender, "Sender address must be the same as CPO address");
        require(isCPO(CPOaddress), "CPO address not registered CPO");
        require(isEV(EVaddress), "EV address not registered EV");

        Deal memory proposedDeal = deals[EVaddress][CPOaddress];
        if ( proposedDeal.EV == address(0) ) {
            revert("Deal does not exist");
        }
        else if ( proposedDeal.accepted ) {
            revert("Deal already accepted");
        }
        else if ( proposedDeal.id != dealId ) {
            revert("Wrong deal ID, proposed deal might have changed");
        }

        proposedDeal.accepted = accepted;

        if ( !accepted ) {
            removeDeal(EVaddress, CPOaddress);
        }
        else {
            deals[EVaddress][CPOaddress] = proposedDeal;
        }

        emit RespondDeal(EVaddress, CPOaddress, accepted, proposedDeal);

    }

    function connect(address EVaddress, address CSaddress, uint nonce) public {
        require(msg.sender == EVaddress || msg.sender == CSaddress, "Sender must either be included EV/CS address");
        require(isEV(EVaddress), "EV address not registered EV");
        require(isCS(CSaddress), "CS address not registered CS");
        require(nonce != 0, "Nonce cannot be 0");

        // Check if connection exists
        Connection memory currentConnection = connections[EVaddress][CSaddress];
        if ( currentConnection.EVconnected && currentConnection.CSconnected ) {
            revert("Connection already established");
        }

        if ( msg.sender == EVaddress ) {

            // Check if connection is pending
            if ( currentConnection.nonce == nonce && currentConnection.EVconnected ) {
                revert("Connection is waiting for response from CS party");
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
                revert("Connection is waiting for response from EV party");
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
        require(msg.sender == EVaddress || msg.sender == CSaddress, "Sender must either be included EV/CS address");
        require(isEV(EVaddress), "EV address not registered EV");
        require(isCS(CSaddress), "CS address not registered CS");

        // Check that there exists a connection
        Connection memory currentConnection = connections[EVaddress][CSaddress];
        if ( !(currentConnection.EVconnected && currentConnection.CSconnected ) ) {
            revert("No active connection exists");
        }

        removeConnection(EVaddress, CSaddress);

        emit Disconnection(EVaddress, CSaddress);

    }

    function setRates(address CPOaddress, uint[RATE_SLOTS] calldata rates, uint ratePrecision) public {
        require(msg.sender == CPOaddress, "Sender must be the same as CPO address to add rates to");
        require(isCPO(CPOaddress), "CPO address must be registered CPO");
        require(rates.length == RATE_SLOTS, "Rates array must be in correct intervall");
        require(ratePrecision >= 1000000000, "Rate precision must be at least 1000000000");

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
                revert("Rate precision cannot be altered in new rates.");
            }
            cpo.rate.next = rates;
            cpo.rate.changeDate = getNextRateChange();
        }

        CPOs[CPOaddress] = cpo;

        emit NewRates(CPOaddress, cpo);

    }

    function addDeposit(address EVaddress) public payable {
        require(msg.sender == EVaddress, "Sender must be EV address.");
        deposits[EVaddress] += msg.value;
    }

    function getDeposit(address EVaddress) public view returns (uint) {
        return deposits[EVaddress];
    }

    function withdrawDeposit(address payable EVaddress) public {
        require(msg.sender == EVaddress, "Sender must be EV address.");
        EVaddress.transfer(deposits[EVaddress]);
        deposits[EVaddress] = 0;
    }

    // TODO : Gör så att start time är ett krav att kanske vara i framtiden, så att man inte kan skicka ett startdatum som sedan passerar...
    function requestCharging(address EVaddress, address CSaddress, uint startTime, uint startCharge) payable public {
        require(msg.sender == EVaddress, "Sender must be EV address");
        require(isEV(EVaddress), "EV address must be registered EV");
        require(isCS(CSaddress), "CS address must be registered CS");

        CS memory cs = CSs[CSaddress];
        
        require(isDealActive(EVaddress, cs.cpo), "There is no deal between EV and CS CPO");
        require(isConnected(EVaddress, CSaddress), "EV and CS must be confirmed connected");

        // Calculate ChargingScheme
        uint deposit = msg.value;
        transferToNewRates(cs.cpo);
        PrecisionNumber memory estimate = estimateChargingPrice(EVaddress, CSaddress, startTime, startCharge);

        require(deposit*estimate.precision + deposits[EVaddress]*estimate.precision >= estimate.value, "Total deposit is incufficient");
        
        // Add to deposits
        deposits[EVaddress] += deposit;

        emit RequestCharging(EVaddress, CSaddress, startTime, startCharge);

    }

    function startCharging(address CSaddress, address EVaddress, uint startTime, uint startCharge) public {
        require(msg.sender == CSaddress, "Sender must be CS address");
        require(isCS(CSaddress), "CS address must be registered CS");
        require(isEV(EVaddress), "EV address must be registered EV");

        CS memory cs = CSs[CSaddress];

        require(isDealActive(EVaddress, cs.cpo), "There is no deal between EV and CS CPO");
        require(isConnected(EVaddress, CSaddress), "EV and CS must be confirmed connected");
        
        // Calculate actual scheme
        transferToNewRates(cs.cpo);
        ChargingScheme memory scheme = getChargingScheme(EVaddress, CSaddress, startTime, startCharge);

        // Check funds
        uint deposit = deposits[EVaddress];

        bool sufficientFunds = deposit * scheme.price.precision >= scheme.price.value;
        if ( !sufficientFunds ) {            
            emit InssufficientDeposit(EVaddress, CSaddress);
            revert("EV has inssufficient funds deposited");
        }

        // Everything good, start charging
        scheme.accepted = true;
        chargingSchemes[EVaddress][CSaddress] = scheme;

        emit StartCharging(EVaddress, CSaddress, scheme);

    }

    function estimateChargingPrice(address EVaddress, address CSaddress, uint startTime, uint startCharge) public view returns (PrecisionNumber memory) {
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
    }

    function getChargingScheme(address EVaddress, address CSaddress, uint startTime, uint startCharge) public view returns (ChargingScheme memory) {
        require(msg.sender == EVaddress, "Sender must be EV address");
        require(isEV(EVaddress), "EV address must be registered EV");
        require(isCS(CSaddress), "CS address must be registered CS");
        startTime = (startTime == 0) ? block.timestamp : startTime;

        Triplett memory T = getTriplett(EVaddress, CSaddress);

        // Make sure that there is still a deal active, and that the car is not fully charged
        require(isDealActive(EVaddress, T.cpo._address), "There is no deal between EV and CS CPO");
        require(startCharge < T.ev.maxCapacity && startCharge >= 0, "Current Charge cannot be negative, and must be less than max capacity");

        ChargingScheme memory scheme;
        scheme.startTime = startTime;    

        // Calculate charge time
        uint chargeTime = calculateChargeTimeInSeconds((T.ev.maxCapacity - startCharge), T.cs.powerDischarge, T.ev.batteryEfficiency);
        /*chargeTime = (chargeTime > timeLeft) 
                                ? timeLeft 
                                : chargeTime;*/

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
        /*chargeTime = (chargeTime > timeLeft)
                                ? timeLeft
                                : chargeTime;*/

        scheme.chargeTime = chargeTime;
        scheme.maxTime = maxTime;
        //scheme.endTime = startTime + chargeTime;

        return generateSchemeSlots(scheme, T);
        /*uint elapsedTime;
        uint totalCost;
        uint index = 0;
        while ( chargeTime > 0 ) {
            
            uint currentTime = startTime + elapsedTime;

            uint currentRateIndex = getRateSlot(currentTime); // Current Watt Seconds rate index.
            uint currentRate = (T.cpo.rate.changeDate != 0 && currentTime >= T.cpo.rate.changeDate) 
                                ? T.cpo.rate.next[currentRateIndex]
                                : T.cpo.rate.current[currentRateIndex];
            
            uint nextRateSlot = getNextRateSlot(currentTime); // Unix time for when the next rate starts.

            uint chargingTimeInSlot = (nextRateSlot - currentTime) < chargeTime
                                            ? (nextRateSlot - currentTime) 
                                            : chargeTime; // Seconds in this rate period.

            // Check if slot is used (Max rate limit)
            if ( shouldUseSlot(currentRate, EVaddress, T.cs.cpo ) ) {
                uint slotCost = chargingTimeInSlot * currentRate * T.cs.powerDischarge;

                totalCost += slotCost;
                chargeTime -= chargingTimeInSlot;
                elapsedTime += chargingTimeInSlot; 

                scheme.durations[index] = chargingTimeInSlot;
                scheme.prices[index] = slotCost;
            }
            else {
                scheme.durations[index] = chargingTimeInSlot;
                scheme.prices[index] = 0;
            }

            index++;
        }

        PrecisionNumber memory precisionTotalCost;
        precisionTotalCost.precision = T.cpo.rate.precision;
        precisionTotalCost.value = totalCost;

        scheme.price = precisionTotalCost;
        scheme.slotsUsed = index;

        return scheme;*/
    }
    struct ChargingScheme {
        bool accepted;
        bool finished;
        uint startTime;
        uint chargeTime;
        uint idleTime;
        uint maxTime;
        uint endTime;
        PrecisionNumber price;
        uint slotsUsed;
        uint[RATE_SLOTS*2] durations;
        uint[RATE_SLOTS*2] prices;
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
        scheme.slotsUsed = index;

        return scheme;
    }

    /*
    * PRIVATE FUNCTIONS
    */

    function createCPO(address CPOaddress) private pure returns (CPO memory) {
        CPO memory cpo;
        cpo.exist = true;
        cpo._address = CPOaddress;
        return cpo;
    }
    function getCPO(address CPOaddress) private view returns (CPO memory) {
        return CPOs[CPOaddress];
    }
    function createCS(address CSaddress, address CPOaddress, uint powerDischarge) private pure returns (CS memory) {
        CS memory cs;
        cs.exist = true;
        cs._address = CSaddress;
        cs.cpo = CPOaddress;
        cs.powerDischarge = powerDischarge;
        return cs;    
    }
    function getCS(address CSaddress) private view returns (CS memory) {
        return CSs[CSaddress];
    }
    function createEV(address EVaddress, uint maxCapacitiy, uint batteryEfficiency) private pure returns (EV memory) {
        EV memory ev;
        ev.exist = true;
        ev._address = EVaddress;
        ev.maxCapacity = maxCapacitiy;
        ev.batteryEfficiency = batteryEfficiency;
        return ev;
    }
    function getEV(address EVaddress) private view returns (EV memory) {
        return EVs[EVaddress];
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

    function isDealActive(address EVaddress, address CPOaddress) private view returns (bool) {
        return deals[EVaddress][CPOaddress].accepted && deals[EVaddress][CPOaddress].endDate > block.timestamp;
    }

    function isConnected(address EVaddress, address CSaddress) private view returns (bool) {
        return connections[EVaddress][CSaddress].EVconnected && connections[EVaddress][CSaddress].CSconnected;
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