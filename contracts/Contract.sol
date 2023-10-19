// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

contract Contract {
    
    /*
    * VARIABLES
    */

    mapping(address => Role) entities; // CPO/CS/EV -> Role
    mapping(address => address) relations; // CS -> CPO
    mapping(address => mapping(address => Deal)) deals; // EV -> CPO -> Deal
    mapping(address => uint) deposits; // EV deposits

    enum Role { NONE, CPO, CS, EV }

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

    /*
    * EVENTS
    */

    event RegisteredCPO(address cpo);
    event RegisteredCS(address cs, address cpo);
    event RegisteredEV(address ev);
    event ProposedDeal(address indexed ev, address indexed cpo, Deal deal);
    event RevertProposedDeal(address indexed ev, address indexed cpo, Deal deal);
    event RespondDeal(address indexed ev, address indexed cpo, bool accepted, Deal deal);

    /*
    * PUBLIC FUNCTIONS
    */

    function isRegistered(address target) public view returns (bool) {
        return entities[target] != Role.NONE;
    }
    function isRole(address target, Role role) public view returns (bool) {
        require(isRegistered(target), "Address must be registered!");
        return entities[target] == role;
    }

    function registerCPO(address CPOaddress) public {
        require(CPOaddress == msg.sender, "Sender address must be the same as register address");
        require(!isRegistered(CPOaddress), "CPO already registered");

        entities[CPOaddress] = Role.CPO;

        emit RegisteredCPO(CPOaddress);
    }

    function registerCS(address CPOaddress, address CSaddress) public {
        require(CPOaddress == msg.sender, "Sender address must be the same as register address");
        require(isRole(CPOaddress, Role.CPO), "Sender is not a CPO");
        require(!isRegistered(CSaddress), "CS already registered");

        entities[CSaddress] = Role.CS;
        relations[CSaddress] = CPOaddress;

        emit RegisteredCS(CSaddress, CPOaddress);
    }

    function registerEV(address EVaddress) public {
        require(EVaddress == msg.sender, "Sender address must be the same as register address");
        require(!isRegistered(EVaddress), "EV already registered");

        entities[EVaddress] = Role.EV;

        emit RegisteredEV(EVaddress);
    }

    function proposeDeal(address EVaddress, address CPOaddress) public {
        require(EVaddress == msg.sender, "Sender address must be the same as EV address");
        require(isRole(EVaddress, Role.EV), "EV address not registered EV");
        require(isRole(CPOaddress, Role.CPO), "CPO address not registered CPO");

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
        require(isRole(EVaddress, Role.EV), "EV address not registered EV");
        require(isRole(CPOaddress, Role.CPO), "CPO address not registered CPO");

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
        require(isRole(CPOaddress, Role.CPO), "CPO address not registered CPO");
        require(isRole(EVaddress, Role.EV), "EV address not registered EV");

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

    /*
    * PRIVATE FUNCTIONS
    */

    function getNextDealId() private returns (uint) {
        nextDealId++;
        return nextDealId;
    }

    function removeDeal(address EVaddres, address CPOaddress) private {
        Deal memory placeholder;
        deals[EVaddres][CPOaddress] = placeholder;
    }

}