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

    constructor () {
        owner = msg.sender;
    }

    function set(address contractAddress) public {
        require(msg.sender == owner, "101");

        contractInstance = IContract(contractAddress);
    }

    /*
    * PUBLIC FUNCTIONS
    */

    function proposeDeal(address EVaddress, address CPOaddress, uint dealId) public view returns (Deal memory) {
        require(EVaddress == msg.sender, "102");
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
            id: dealId,
            EV: EVaddress,
            CPO: CPOaddress,
            accepted: false,
            onlyRewneableEnergy: false,
            maxRate: maxRate,
            allowSmartCharging: true,
            startDate: block.timestamp,
            endDate: block.timestamp + 1 days
        });

        return proposedDeal;
    }

    function verifyDealInfo(address EVaddress, address CPOaddress, uint dealId, Deal memory deal) public view {
        require(EVaddress == msg.sender, "402");
        require(contractInstance.isEV(EVaddress), "403");
        require(contractInstance.isCPO(CPOaddress), "203");
        if ( deal.EV == address(0) ) {
            revert("503");
        }
        else if ( deal.accepted ) {
            revert("504");
        }
        else if ( deal.id != dealId ) {
            revert("505");
        }
    }

}