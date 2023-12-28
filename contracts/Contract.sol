// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';
import './IContract.sol';
import './IEntity.sol';
import './IAgreement.sol';
import './IConnection.sol';
import './IRate.sol';
import './ICharging.sol';

contract Contract is Structure, IContract {
    
    /*
    * CONTRACT MANAGMENT
    */
    address owner;
    IEntity entityInstance;
    IAgreement agreementInstance;
    IConnection connectionInstance;
    IRate rateInstance;
    ICharging chargingInstance;

    constructor () {
        owner = msg.sender;
    }

    function set(address entityAddress, address agreementAddress, address connectionAddress, address rateAddress, address chargingAddress) public {
        require(msg.sender == owner, "101");
        entityInstance = IEntity(entityAddress);
        agreementInstance = IAgreement(agreementAddress);
        connectionInstance = IConnection(connectionAddress);
        rateInstance = IRate(rateAddress);
        chargingInstance = ICharging(chargingAddress);
    }
    

    /*
    * VARIABLES
    */ 
    mapping(address => CPO) CPOs;
    mapping(address => CS) CSs;
    mapping(address => EV) EVs;

    mapping(address => mapping(address => Agreement)) agreements; // EV -> CPO -> Agreement

    mapping(address => mapping(address => Connection)) connections; // EV -> CS -> Connection

    mapping(address => mapping(bytes3 => Rate)) rates; // CPO -> Region -> Rate

    mapping(address => mapping(address => ChargingScheme)) chargingSchemes; // EV -> CS -> CharginScheme
    
    mapping(address => uint) deposits; // EV deposits

    /*
    * EVENTS
    */

    event CPORegistered(address indexed cpo);
    event CSRegistered(address indexed cs, address indexed cpo);
    event EVRegistered(address indexed ev);

    event AgreementProposed(address indexed ev, address indexed cpo, Agreement agreement);
    event AgreementProposalReverted(address indexed ev, address indexed cpo);
    event AgreementResponded(address indexed ev, address indexed cpo, bool accepted, Agreement agreement);

    event ConnectionMade(address indexed ev, address indexed cs, Connection connection);
    event Disconnection(address indexed ev, address indexed cs);

    event NewRates(address indexed cpo, bytes3 region, Rate rates);

    event ChargingRequested(address indexed ev, address indexed cs, ChargingScheme scheme);
    event InssufficientDeposit(address indexed ev, address indexed cs);
    event ChargingSchemeTimeout(address indexed ev, address indexed cs, ChargingScheme scheme);
    event ChargingAcknowledged(address indexed ev, address indexed cs, ChargingScheme scheme);
    event ChargingStopped(address indexed ev, address indexed cs, ChargingScheme scheme, uint finalPriceInWei, uint finalRoamingPriceInWei);

    event SmartChargingScheduled(address indexed ev, address indexed cs, ChargingScheme scheme);

    event Payment(address indexed from, address indexed to, uint amount);

    /*
    * PUBLIC FUNCTIONS
    */

    function isRegistered(address target) public view returns (bool) {
        return CPOs[target]._address != address(0) || CSs[target]._address != address(0) || EVs[target]._address != address(0);
    }
    function isCPO(address target) public view returns (bool) {
        return CPOs[target]._address != address(0);
    }
    function getCPO(address target) public view returns (CPO memory) {
        return CPOs[target];
    }
    function isCS(address target) public view returns (bool) {
        return CSs[target]._address != address(0);
    }
    function getCS(address target) public view returns (CS memory) {
        return CSs[target];
    }
    function isEV(address target) public view returns (bool) {
        return EVs[target]._address != address(0);
    }
    function getEV(address target) public view returns (EV memory) {
        return EVs[target];
    }
    function getTriplett(address EVaddress, address CSaddress, address CPOaddress) public view returns (Triplett memory) {
        return Triplett({
            ev: EVs[EVaddress],
            cs: CSs[CSaddress],
            cpo: CPOs[CPOaddress]
        });
    }
    /*function getTriplett(address EVaddress, address CSaddress) public view returns (Triplett memory) {
        return getTriplett(EVaddress, CSaddress, CSs[CSaddress].cpo);
    }*/

    function getAgreement(address EVaddress, address CPOaddress) public view returns (Agreement memory) {
        return agreements[EVaddress][CPOaddress];
    }
    function isAgreementActive(address EVaddress, address CPOaddress) public view returns (bool) {
        return agreements[EVaddress][CPOaddress].accepted && agreements[EVaddress][CPOaddress].endDate > block.timestamp;
    }

    function getConnection(address EVaddress, address CSaddress) public view returns (Connection memory) {
        return connections[EVaddress][CSaddress];
    }
    function isConnected(address EVaddress, address CSaddress) public view returns (bool) {
        return connections[EVaddress][CSaddress].EVconnected && connections[EVaddress][CSaddress].CSconnected;
    }

    function getRate(address CPOaddress, bytes3 region) public view returns (Rate memory) {
        return rates[CPOaddress][region];
    }
    function transferToNewRates(address CPOaddress, bytes3 region) public {
        rates[CPOaddress][region] = rateInstance.transferToNewRates(rates[CPOaddress][region], CPOs[CPOaddress].automaticRates);
    }
    function updateAutomaticRates() public {
        rateInstance.updateAutomaticRates();
    }

    function isCharging(address EVaddress, address CSaddress) public view returns (bool) {
        ChargingScheme memory scheme = chargingSchemes[EVaddress][CSaddress];
        return scheme.CSaccepted && scheme.EVaccepted && !scheme.finished;
    }
    function getCharging(address EVaddress, address CSaddress) public view returns (ChargingScheme memory) {
        return chargingSchemes[EVaddress][CSaddress];
    }
    function isSmartCharging(address EVaddress, address CSaddress) public view returns (bool) {
        ChargingScheme memory scheme = chargingSchemes[EVaddress][CSaddress];
        return scheme.smartCharging && scheme.CSaccepted && scheme.EVaccepted && !scheme.finished;
    }
    function isRatesAvailable(address CPOaddress, bytes3 region) public view returns (bool) {
        return rates[CPOaddress][region].current[0] != 0;
    }
    function isRoamingAvailable(address CPOaddress, bytes3 region) public view returns (bool) {
        return rates[CPOaddress][region].currentRoaming != 0;
    }
    
    /*
    * CONTRACT USER INTERFACES
    */ 

    function registerCPO(address CPOaddress, bytes5 name, bool automaticRates) public {
        CPOs[CPOaddress] = entityInstance.createCPO(CPOaddress, name, automaticRates);
        emit CPORegistered(CPOaddress);
    }
    function registerCS(address CSaddress, address CPOaddress, bytes3 region, uint powerDischarge, bool hasRenewableEnergy) public {
        CSs[CSaddress] = entityInstance.createCS(CSaddress, CPOaddress, region, powerDischarge, hasRenewableEnergy);
        emit CSRegistered(CSaddress, CPOaddress);
    }
    function registerEV(address EVaddress, uint maxCapacity, uint batteryEfficiency) public {
        EVs[EVaddress] = entityInstance.createEV(EVaddress, maxCapacity, batteryEfficiency);
        emit EVRegistered(EVaddress);
    }



    function proposeAgreement(address EVaddress, address CPOaddress, AgreementParameters calldata agreementParameters) public {
        Agreement memory proposedAgreement = agreementInstance.proposeAgreement(EVaddress, CPOaddress, agreementParameters);
        agreements[EVaddress][CPOaddress] = proposedAgreement;
        emit AgreementProposed(EVaddress, CPOaddress, proposedAgreement);
    }
    function revertProposedAgreement(address EVaddress, address CPOaddress, uint agreementId) public {
        agreements[EVaddress][CPOaddress] = agreementInstance.revertProposedAgreement(EVaddress, CPOaddress, agreementId);
        emit AgreementProposalReverted(EVaddress, CPOaddress);
    }
    function respondAgreement(address EVaddress, address CPOaddress, bool accepted, uint agreementId) public {
        Agreement memory proposedAgreement = agreementInstance.respondAgreement(EVaddress, CPOaddress, accepted, agreementId);
        agreements[EVaddress][CPOaddress] = proposedAgreement;
        emit AgreementResponded(EVaddress, CPOaddress, accepted, proposedAgreement);
    }



    function connect(address EVaddress, address CSaddress, uint nonce) public {
        Connection memory connection = connectionInstance.connect(EVaddress, CSaddress, nonce);
        connections[EVaddress][CSaddress] = connection;
        emit ConnectionMade(EVaddress, CSaddress, connection);
    }
    function disconnect(address EVaddress, address CSaddress) public {
        connections[EVaddress][CSaddress] = connectionInstance.disconnect(EVaddress, CSaddress);
        emit Disconnection(EVaddress, CSaddress);

        // Stop charging if charging is active
        if ( isCharging(EVaddress, CSaddress) ) {
            stopCharging(EVaddress, CSaddress); 
        }
    }



    function setRates(address CPOaddress, bytes3 region, uint[RATE_SLOTS] calldata newRates, uint newRoaming, uint ratePrecision) public {
        Rate memory rate = rateInstance.setRates(CPOaddress, region, newRates, newRoaming, ratePrecision);
        rates[CPOaddress][region] = rate;
        emit NewRates(CPOaddress, region, rate);
    } 
    function nextRoaming(address CPOaddress, bytes3 region, uint newRoaming, uint roamingPrecision) public {
        Rate memory rate = rateInstance.nextRoaming(CPOaddress, region, newRoaming, roamingPrecision);
        rates[CPOaddress][region] = rate;
        emit NewRates(CPOaddress, region, rate);
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



    function requestCharging(address EVaddress, address CSaddress, address CPOaddress, uint startTime, uint startCharge, uint targetCharge) payable public {
        ChargingScheme memory scheme = chargingInstance.requestCharging(EVaddress, CSaddress, CPOaddress, startTime, startCharge, targetCharge, msg.value);

        // Add to deposits
        deposits[EVaddress] += msg.value;
        chargingSchemes[EVaddress][CSaddress] = scheme;

        emit ChargingRequested(EVaddress, CSaddress, scheme);
    }
    function acknowledgeCharging(address EVaddress, address CSaddress, uint schemeId) public {
        ChargingScheme memory scheme = chargingInstance.acknowledgeCharging(EVaddress, CSaddress, schemeId);

        // Timeout
        if ( scheme.id == 0 ) {
            emit ChargingSchemeTimeout(EVaddress, CSaddress, scheme);
            chargingSchemes[EVaddress][CSaddress] = scheme;
            revert("705");
        }

        chargingSchemes[EVaddress][CSaddress] = scheme;
        emit ChargingAcknowledged(EVaddress, CSaddress, scheme);
    }
    function stopCharging(address EVaddress, address CSaddress) public {
        ChargingScheme memory scheme = chargingInstance.stopCharging(EVaddress, CSaddress);
        chargingSchemes[EVaddress][CSaddress] = scheme;
        Triplett memory T = getTriplett(EVaddress, CSaddress, scheme.CPOaddress);

        // Transfer funds
        uint priceInWei = scheme.finalPriceInWei;
        payable(scheme.CPOaddress).transfer(priceInWei);
        deposits[EVaddress] -= priceInWei;
        emit Payment(EVaddress, scheme.CPOaddress, priceInWei);

        uint roamingPriceInWei = scheme.finalRoamingPriceInWei;
        if ( scheme.roaming ) {
            payable(T.cs.cpo).transfer(roamingPriceInWei);
            deposits[EVaddress] -= roamingPriceInWei;
            emit Payment(EVaddress, T.cs.cpo, roamingPriceInWei);
        }

        // Deposits kickback
        uint remaining = deposits[EVaddress];
        payable(EVaddress).transfer(remaining);
        deposits[EVaddress] -= remaining;

        // Inform about charging scheme termination
        emit ChargingStopped(EVaddress, CSaddress, scheme, priceInWei, roamingPriceInWei);
    }
    function getChargingScheme(address EVaddress, address CSaddress, address CPOaddress, uint startTime, uint startCharge, uint targetCharge) public view returns (ChargingScheme memory) {
        return chargingInstance.getChargingScheme(EVaddress, CSaddress, CPOaddress, startTime, startCharge, targetCharge);
    }



    function scheduleSmartCharging(address EVaddress, address CSaddress, address CPOaddress, uint startCharge, uint endDate) public {
        // Get smart charging spot
        ChargingScheme memory scheme = chargingInstance.scheduleSmartCharging(EVaddress, CSaddress, CPOaddress, startCharge, endDate);
        chargingSchemes[EVaddress][CSaddress] = scheme;

        // Emit event regarding smart charging
        emit SmartChargingScheduled(EVaddress, CSaddress, scheme);
    }
    function acceptSmartCharging(address EVaddress, address CSaddress, uint schemeId) public payable {
        ChargingScheme memory scheme = chargingInstance.acceptSmartCharging(EVaddress, CSaddress, schemeId, msg.value);

        // Timeout
        if ( scheme.id == 0 ) {
            emit ChargingSchemeTimeout(EVaddress, CSaddress, scheme);
            chargingSchemes[EVaddress][CSaddress] = scheme;
            revert("705");
        }

        // Add to deposits, and add smart charging scheme, waiting for its acceptance
        deposits[EVaddress] += msg.value;
        chargingSchemes[EVaddress][CSaddress] = scheme;
        emit ChargingRequested(EVaddress, CSaddress, scheme);
    }

    /*
    * PRIVATE FUNCTIONS
    */

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