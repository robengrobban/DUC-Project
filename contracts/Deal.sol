// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';
import './IDeal.sol';
import './IContract.sol';

contract Deal is Structure, IDeal {

    /*
    * CONTRACT MANAGMENT
    */
    address owner;
    IContract contractInstance;
    address contractAddress;

    constructor () {
        owner = msg.sender;
    }

    function set(address _contractAddress) public {
        require(msg.sender == owner, "101");

        contractInstance = IContract(_contractAddress);
        contractAddress = _contractAddress;
    }
    
    /*
    * VARIABLES
    */

    uint nextDealId = 0;

    /*
    * PUBLIC FUNCTIONS
    */

    function proposeDeal(address EVaddress, address CPOaddress) public returns (Deal memory) {
        require(msg.sender == contractAddress, "102");
        require(EVaddress == tx.origin, "402");
        require(contractInstance.isEV(EVaddress), "402");
        require(contractInstance.isCPO(CPOaddress), "203");

        Deal memory currentDeal = contractInstance.getDeal(EVaddress, CPOaddress);
        if ( currentDeal.EV != address(0) && !currentDeal.accepted && currentDeal.endDate > block.timestamp ) {
            revert("501");
        }
        else if ( contractInstance.isDealActive(EVaddress, CPOaddress) ) {
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
            endDate: block.timestamp + 1 weeks
        });

        return proposedDeal;
    }

    function revertProposedDeal(address EVaddress, address CPOaddress, uint dealId) public view returns (Deal memory) {
        require(msg.sender == contractAddress, "102");
        require(EVaddress == tx.origin, "402");
        require(contractInstance.isEV(EVaddress), "403");
        require(contractInstance.isCPO(CPOaddress), "203");

        Deal memory deal = contractInstance.getDeal(EVaddress, CPOaddress);

        require(deal.EV != address(0), "503");
        require(!deal.accepted, "504");
        require(deal.id == dealId, "505");

        Deal memory deleted;
        return deleted;
    }

    function respondDeal(address CPOaddress, address EVaddress, bool accepted, uint dealId) public view returns (Deal memory) {
        require(msg.sender == contractAddress, "102");
        require(CPOaddress == tx.origin, "202");
        require(contractInstance.isCPO(CPOaddress), "203");
        require(contractInstance.isEV(EVaddress), "403");

        Deal memory deal = contractInstance.getDeal(EVaddress, CPOaddress);

        require(deal.EV != address(0), "503");
        require(!deal.accepted, "504");
        require(deal.id == dealId, "505");

        if ( accepted ) {
            deal.accepted = accepted;
            return deal;
        }
        Deal memory deleted;
        return deleted;    
    }

    /*
    * PRIVATE FUNCTIONS
    */

    function getNextDealId() private returns (uint) {
        nextDealId++;
        return nextDealId;
    }

}