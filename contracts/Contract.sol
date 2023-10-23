// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

contract Contract {
    
    /*
    * VARIABLES
    */

    mapping(address => CPO) CPOs;
    mapping(address => CS) CSs;
    mapping(address => EV) EVs;    
    mapping(address => address) relations; // CS -> CPO

    struct CPO {
        bool exist;
        uint[60] rates; // Rate each minute
    }
    struct CS {
        bool exist;
        uint powerDischarge; // Watt output
    }
    struct EV {
        bool exist;
        uint stateOfCharge; // Watt Minutes of charge
        uint maxCapacity; // Watt Minutes of max charge
        int batteryEfficency; // Battery charge efficency
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

    function registerCS(address CPOaddress, address CSaddress) public {
        require(CPOaddress == msg.sender, "Sender address must be the same as register address");
        require(isCPO(CPOaddress), "Sender is not a CPO");
        require(!isRegistered(CSaddress), "CS already registered");

        CSs[CSaddress] = createCS();
        relations[CSaddress] = CPOaddress;

        emit RegisteredCS(CSaddress, CPOaddress);
    }

    function registerEV(address EVaddress) public {
        require(EVaddress == msg.sender, "Sender address must be the same as register address");
        require(!isRegistered(EVaddress), "EV already registered");

        EVs[EVaddress] = createEV();

        emit RegisteredEV(EVaddress);
    }

    function proposeDeal(address EVaddress, address CPOaddress) public {
        require(EVaddress == msg.sender, "Sender address must be the same as EV address");
        require(isEV(EVaddress), "EV address not registered EV");
        require(isCPO(CPOaddress), "CPO address not registered CPO");

        Deal memory currentDeal = deals[EVaddress][CPOaddress];
        if ( currentDeal.EV != address(0) && !currentDeal.accepted ) {
            revert("Deal already proposed, waiting response");
        }
        else if ( currentDeal.accepted ) {
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

        emit RespondDeal(EVaddress, CPOaddress, accepted, proposedDeal);

    }

    function connect(address EVaddress, address CSaddress, uint nonce) public {
        require(msg.sender == EVaddress || msg.sender == CSaddress, "Sender must either be included EV/CS address");
        require(isEV(EVaddress), "EV address not registered EV");
        require(isCS(CSaddress), "CS address not registered CS");

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

            currentConnection.EV = EVaddress;
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

    /*
    * PRIVATE FUNCTIONS
    */

    function createCPO() private pure returns (CPO memory) {
        CPO memory cpo;
        cpo.exist = true;
        return cpo;
    }
    function createCS() private pure returns (CS memory) {
        CS memory cs;
        cs.exist = true;
        return cs;    
    }
    function createEV() private pure returns (EV memory) {
        EV memory ev;
        ev.exist = true;
        return ev;
    }

    function getNextDealId() private returns (uint) {
        nextDealId++;
        return nextDealId;
    }

    function removeDeal(address EVaddres, address CPOaddress) private {
        Deal memory placeholder;
        deals[EVaddres][CPOaddress] = placeholder;
    }

    function removeConnection(address EVaddress, address CPOaddress) private {
        Connection memory placeholder;
        connections[EVaddress][CPOaddress] = placeholder;
    }

}