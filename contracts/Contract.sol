// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

contract Contract {
    
    /*
    * VARIABLES
    */

    mapping(address => bool) internal registeredCPO; // list of registered CPO
    mapping(address => address) internal registeredCS; // list of registered CS connect to CPO
    mapping(address => bool) internal registeredEV; // list of registered EV

    struct Contract 

    /*
    * EVENTS
    */

    event RegisteredCPO(address cpo);
    event RegisteredCS(address cs, address cpo);
    event RegisteredEV(address ev);

    /*
    * FUNCTIONS
    */

    function isRegistered(address check) public view returns (bool) {
        return registeredCPO[check] || registeredCS[check] != address(0) || registeredEV[check];
    }
    function isCPO(address check) public view returns (bool) {
        return registeredCPO[check];
    }
    function isCS(address check) public view returns (bool) {
        return registeredCS[check] != address(0);
    }
    function isEV(address check) public view returns (bool) {
        return registeredEV[check];
    }

    function registerCPO() public {
        address newCPO = msg.sender;
        require(!isRegistered(newCPO), "Address already registered");
        registeredCPO[newCPO] = true;
        emit RegisteredCPO(newCPO);
    }
    function registerCS(address newCS) public {
        address CPO = msg.sender;
        require(isCPO(CPO), "Sender is not a CPO");
        require(!isRegistered(newCS), "Address already registered");
        registeredCS[newCS] = CPO;
        emit RegisteredCS(newCS, CPO);
    }
    function registerEV() public {
        address newEV = msg.sender;
        require(!isRegistered(newEV), "Address already registered");
        registeredEV[newEV] = true;
        emit RegisteredEV(newEV);
    }


}