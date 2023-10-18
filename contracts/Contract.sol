// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

contract Contract {
    
    /*
    * VARIABLES
    */

    mapping(address => Role) entities; // CPO/CS/EV -> Role
    // mapping(address => Entity) entities; // CPO/CS/EV -> Entity
    mapping(address => address) relations; // CS -> CPO
    mapping(address => mapping(address => Deal)) deals; // EV -> CPO -> Deal
    //mapping(address => Deal[]) deals; var det förut ^^^
    mapping(address => mapping(address => Deal)) pendingDeals; // CPO -> EV -> Deal

    enum Role { CPO, CS, EV }
    /*struct Entity {
        Role role;
        address entityAddress;
        Deal[] deals;
        Entity[] relations;
    }*/

    struct Deal {
        address EV;
        address CPO;
        bool onlyRewneableEnergy;
        uint maxRate;
        bool allowSmartCharging;
        uint startDate;
        uint endDate;
    }

    /*
    * EVENTS
    */

    event RegisteredCPO(address cpo);
    event RegisteredCS(address cs, address cpo);
    event RegisteredEV(address ev);
    event ProposedDeal(address indexed cpo, address ev, Deal deal);

    /*
    * FUNCTIONS
    */

    function isRegistered(address target) public view returns (bool) {
        return entities[target] != Role(0);
    }
    function isRole(address target, Role role) public view returns (bool) {
        return entities[target] == role;
    }

    function registerCPO(address CPOaddress) public {
        require(CPOaddress == msg.sender, "Sender address must be the same as register address");
        require(!isRegistered(CPOaddress), "CPO already registered");

        /*entities[CPOaddress] = Entity({
            role: Role.CPO,
            entityAddress: CPOaddress,
            deals: new Deal[](0),
            relations: new Entity[](0)
        });*/
        entities[CPOaddress] = Role.CPO;

        emit RegisteredCPO(CPOaddress);
    }

    function registerCS(address CPOaddress, address CSaddress) public {
        require(CPOaddress == msg.sender, "Sender address must be the same as register address");
        require(isRole(CPOaddress, Role.CPO), "Sender is not a CPO");
        require(!isRegistered(CSaddress), "CS already registered");

        /*entities[CSaddress] = Entity({
            role: Role.CS,
            entityAddress: CSaddress,
            deals: new Deal[](0),
            relations: new Entity[](0)
        });*/
        entities[CSaddress] = Role.CS;
        relations[CSaddress] = CPOaddress;

        emit RegisteredCS(CSaddress, CPOaddress);
    }

    function registerEV(address EVaddress) public {
        require(EVaddress == msg.sender, "Sender address must be the same as register address");
        require(!isRegistered(EVaddress), "EV already registered");

        /*entities[EVaddress] = Entity({
            role: Role.EV,
            entityAddress: EVaddress,
            deals: new Deal[](0),
            relations: new Entity[](0)
        });*/
        entities[EVaddress] = Role.EV;

        emit RegisteredEV(EVaddress);
    }

    function proposeDeal(address EVaddress, address CPOaddress) public {
        require(EVaddress == msg.sender, "Sender address must be the same as EV address");
        require(isRegistered(EVaddress), "EV is not registered");
        require(isRegistered(CPOaddress), "CPO is not registered");

        Deal memory proposedDeal = Deal({
            EV: EVaddress,
            CPO: CPOaddress,
            onlyRewneableEnergy: false,
            maxRate: 500,
            allowSmartCharging: true,
            startDate: block.timestamp,
            endDate: block.timestamp + 1 days
        });

        pendingDeals[CPOaddress][EVaddress] = proposedDeal;

        emit ProposedDeal(CPOaddress, EVaddress, proposedDeal);

    }

    function respondDeal(address CPOaddress, address EVaddress) public {
        require(CPOaddress == msg.sender, "Sender address must be the same as CPO address");
        require(isRegistered(CPOaddress), "CPO is not registered");
        require(isRegistered(EVaddress), "EV is not registered");
    }


}