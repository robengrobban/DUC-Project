// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

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

    uint constant RATE_CHARGE_PERIOD = RATE_CHANGE_IN_SECONDS / RATE_SLOTS; // This gives how many seconds are in one rate charge period
                                                                            // If rate changes every hour, and have a new price every minute
                                                                            // That means that there are 60 seconds to account for in each 
                                                                            // rate charging period.
                                                                            // If hourly rate are user -> 86400 / 24 = 3600, there are so many seconds
                                                                            // in one hour, which is one charging period.
                                                                            // This is important as prices are related to this, so RATE_CHARGE_PERIOD
                                                                            // are the amount of seconds that needs to pass in order for the full charge
                                                                            // rate price to be accounted for. 

    uint constant PRECISION = 10000;                 // Affects the precision on calculation, as they are all integer calulcations.
    struct PrecisionNumber {
        uint value;
        uint precision;
    }

    mapping(address => CPO) CPOs;
    mapping(address => CS) CSs;
    mapping(address => EV) EVs;

    struct CPO {
        bool exist;
        Rate rate;
    }
    struct Rate {
        PrecisionNumber[RATE_SLOTS] current; // Rate in Watt seconds
        uint startDate; // The date when the rates was applied

        PrecisionNumber[RATE_SLOTS] next; // The next scheduled rates
        uint changeDate; // The date when the new rates are expected to change

        PrecisionNumber[RATE_SLOTS] historical; // What the last rate was
    }
    struct CS {
        bool exist;
        uint powerDischarge; // Watt output
        address cpo; // Connection to what CPO
    }
    struct EV {
        bool exist;
        uint stateOfCharge; // Watt Minutes of charge
        uint maxCapacity; // Watt Minutes of max charge
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
        uint maxRate;
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

    mapping(address => uint) deposits; // EV deposits


    

    

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

        CPOs[CPOaddress] = createCPO();

        emit RegisteredCPO(CPOaddress);
    }

    function registerCS(address CPOaddress, address CSaddress, uint powerDischarge) public {
        require(CPOaddress == msg.sender, "Sender address must be the same as register address");
        require(isCPO(CPOaddress), "Sender is not a CPO");
        require(!isRegistered(CSaddress), "CS already registered");
        require(powerDischarge > 0, "Power discharg must be greater than 0");

        CSs[CSaddress] = createCS(CPOaddress, powerDischarge);

        emit RegisteredCS(CSaddress, CPOaddress);
    }

    function registerEV(address EVaddress, uint maxCapacity, uint batteryEfficiency) public {
        require(EVaddress == msg.sender, "Sender address must be the same as register address");
        require(!isRegistered(EVaddress), "EV already registered");
        require(maxCapacity != 0, "Max battery capacity cannot be set to 0");
        require(batteryEfficiency > 0 && batteryEfficiency < 100, "Battery efficiency must be between 0 and 100, but not be 0 or 100");

        EVs[EVaddress] = createEV(maxCapacity, batteryEfficiency);

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

        Deal memory proposedDeal = Deal({
            id: getNextDealId(),
            EV: EVaddress,
            CPO: CPOaddress,
            accepted: false,
            onlyRewneableEnergy: false,
            maxRate: 500,
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

    function disconnection(address EVaddress, address CSaddress) public {
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

    function setRates(address CPOaddress, PrecisionNumber[RATE_SLOTS] calldata rates) public {
        require(msg.sender == CPOaddress, "Sender must be the same as CPO address to add rates to");
        require(isCPO(CPOaddress), "CPO address must be registered CPO");
        require(rates.length == RATE_SLOTS, "Rates array must be in correct intervall");

        CPO memory currentCPO = CPOs[CPOaddress];
        // There are no current rates
        if ( currentCPO.rate.current[0].value == 0 ) {
            currentCPO.rate.startDate = block.timestamp;
            currentCPO.rate.current = rates;
        }
        // There are existing rates.
        else {
            currentCPO.rate.next = rates;
            currentCPO.rate.changeDate = getNextRateChange();
        }

        CPOs[CPOaddress] = currentCPO;

        emit NewRates(CPOaddress, currentCPO);

    }

    function getDeposit(address EVaddress) public view returns (uint) {
        return deposits[EVaddress];
    }

    function estimateChargingPrice(address EVaddress, address CSaddress, uint currentCharge) public view returns (uint) {
        require(msg.sender == EVaddress, "Sender must be EV address");
        require(isEV(EVaddress), "EV address must be registered EV");
        require(isCS(CSaddress), "CS address must be registered CS");

        EV memory ev = EVs[EVaddress];
        CS memory cs = CSs[CSaddress];
        CPO memory cpo = CPOs[cs.cpo];

        // Make sure that there is still a deal active, and that the car is not fully charged
        require(isDealActive(EVaddress, cs.cpo), "There is no deal between EV and CS CPO");
        require(currentCharge < ev.maxCapacity && currentCharge >= 0, "Current Charge cannot be negative, and must be less than max capacity");

        // Calculate charge time, and adjust it if the deal ends before fully charged.
        uint startTime = block.timestamp;
        uint chargeTime = calculateChargeTimeInSeconds(currentCharge, cs.powerDischarge, ev.batteryEfficiency);
        uint dealTimeLeft = deals[EVaddress][cs.cpo].endDate - startTime;
        uint adjustedChargeTime = chargeTime > dealTimeLeft ? chargeTime - dealTimeLeft : chargeTime;

        uint currentTime = startTime;
        uint totalCost;
        while ( adjustedChargeTime > 0 ) {
            
            uint currentRate = getRateIntervalAt(currentTime);
            uint nextRateSlot = getNextRateSlot(currentTime);

            uint chargingTimeInSlot = nextRateSlot - currentTime;



        }





    }

    function requestCharging(address EVaddress, address CSaddress) payable public {
        require(msg.sender == EVaddress, "Sender must be EV address");
        require(isEV(EVaddress), "EV address must be registered EV");
        require(isCS(CSaddress), "CS address must be registered CS");

        CS memory currentCS = CSs[CSaddress];
        
        require(isDealActive(EVaddress, currentCS.cpo), "There is no deal between EV and CS CPO");

        transferToNewRates(currentCS.cpo);

        // Calculate ChargingScheme
        uint deposit = msg.value;
        uint totalPrice = 0;

        require(deposit >= totalPrice, "Total deposit is incufficient");

    }

    /*
    * PRIVATE FUNCTIONS
    */

    function createCPO() private pure returns (CPO memory) {
        CPO memory cpo;
        cpo.exist = true;
        return cpo;
    }
    function createCS(address CPOaddress, uint powerDischarge) private pure returns (CS memory) {
        CS memory cs;
        cs.exist = true;
        cs.cpo = CPOaddress;
        cs.powerDischarge = powerDischarge;
        return cs;    
    }
    function createEV(uint maxCapacitiy, uint batteryEfficiency) private pure returns (EV memory) {
        EV memory ev;
        ev.exist = true;
        ev.maxCapacity = maxCapacitiy;
        ev.batteryEfficiency = batteryEfficiency;
        return ev;
    }

    function createPrecisionNumber() private pure returns (PrecisionNumber memory) {
        PrecisionNumber memory number;
        number.precision = PRECISION;
        return number;
    }

    function getNextDealId() private returns (uint) {
        nextDealId++;
        return nextDealId;
    }

    function isDealActive(address EVaddress, address CPOaddress) private view returns (bool) {
        return deals[EVaddress][CPOaddress].accepted && deals[EVaddress][CPOaddress].endDate > block.timestamp;
    }

    function removeDeal(address EVaddres, address CPOaddress) private {
        Deal memory placeholder;
        deals[EVaddres][CPOaddress] = placeholder;
    }

    function removeConnection(address EVaddress, address CPOaddress) private {
        Connection memory placeholder;
        connections[EVaddress][CPOaddress] = placeholder;
    }

    function getNextRateChange() private view returns (uint) {
        uint currentTime = block.timestamp;
        uint secondsUntilRateChange = RATE_CHANGE_IN_SECONDS - (currentTime % RATE_CHANGE_IN_SECONDS);
        return currentTime + secondsUntilRateChange;
    }

    function getNextRateSlot(uint currentTime) private pure returns (uint) {
        uint secondsUntilRateChange = RATE_CHARGE_PERIOD - (currentTime % RATE_CHARGE_PERIOD);
        return currentTime + secondsUntilRateChange;
    }

    function getRateIntervalAt(uint time) private pure returns (uint) {
        return time % RATE_CHANGE_IN_SECONDS;
    }

    function getCurrentRateInterval() private view returns (uint) {
        return getRateIntervalAt(block.timestamp);
    }

    function transferToNewRates(address CPOaddress) private returns (bool) {

        CPO memory currentCPO = CPOs[CPOaddress];

        if ( currentCPO.rate.changeDate != 0 && currentCPO.rate.changeDate <= block.timestamp ) {
            currentCPO.rate.historical = currentCPO.rate.current;

            currentCPO.rate.current = currentCPO.rate.next;
            currentCPO.rate.startDate = block.timestamp;

            PrecisionNumber[60] memory empty;
            currentCPO.rate.next = empty;
            currentCPO.rate.changeDate = 0;

            CPOs[CPOaddress] = currentCPO;

            return true;
        }
        return false;
    }

    function calculateChargeTimeInSeconds(uint charge, uint discharge, uint efficiency) private pure returns (uint) {
        uint time = PRECISION * charge * 100 / (discharge * efficiency);
        // Derived from: charge / (discharge * efficienct/100)

        uint integerPart = time / PRECISION;
        uint fractionalPart = time % PRECISION;

        uint totalSeconds = integerPart * 60;
        totalSeconds += fractionalPart * 60 / PRECISION;

        return totalSeconds;
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

}