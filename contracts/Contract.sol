// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

contract Contract {
    
    /*
    * VARIABLES
    */

    mapping(address => Entity) entities;
    mapping(address => address) relations;

    enum Role { CPO, CS, EV }
    struct Entity {
        Role role;
        address payable address_;
        Deal[] deals;
        Entity[] relations;
    }

    struct Deal {
        Entity EV;
        Entity CPO;
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

    /*
    * FUNCTIONS
    */

    function isRegistered(address target) public view returns (bool) {
        return entities[target].address_ != address(0);
    }
    function isRole(address target, Role role) public view returns (bool) {
        return entities[target].role == role;
    }

    function registerCPO(address payable CPOaddress) public {
        require(CPOaddress == msg.sender, "Sender address must be the same as register address");
        require(!isRegistered(CPOaddress), "Address already registered");

        entities[CPOaddress] = Entity({
            role: Role.CPO,
            address_: CPOaddress,
            deals: new Deal[](0),
            relations: new Entity[](0)
        });

        emit RegisteredCPO(CPOaddress);
    }

    function registerCS(address payable CPOaddress, address payable CSaddress) public {
        require(CPOaddress == msg.sender, "Sender address must be the same as register address");
        require(isRole(CPOaddress, Role.CPO), "Sender is not a CPO");
        require(!isRegistered(CSaddress), "Address already registered");

        entities[CSaddress] = Entity({
            role: Role.CS,
            address_: CSaddress,
            deals: new Deal[](0),
            relations: new Entity[](0)
        });

        relations[CSaddress] = CPOaddress;

        emit RegisteredCS(CSaddress, CPOaddress);
    }

    function registerEV(address payable EVaddress) public {
        require(EVaddress == msg.sender, "Sender address must be the same as register address");
        require(!isRegistered(EVaddress), "Address already registered");

        entities[EVaddress] = Entity({
            role: Role.EV,
            address_: EVaddress,
            deals: new Deal[](0),
            relations: new Entity[](0)
        });
        emit RegisteredEV(EVaddress);
    }


}