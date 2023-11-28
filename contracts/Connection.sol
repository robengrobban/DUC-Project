// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';
import './IConnection.sol';
import './IContract.sol';

contract Connection is Structure, IConnection {

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
    * PUBLIC FUNCTIONS
    */

    function connect(address EVaddress, address CSaddress, uint nonce) public view returns (Connection memory) {
        require(msg.sender == contractAddress, "102");
        require(tx.origin == EVaddress || tx.origin == CSaddress, "402/302");
        require(contractInstance.isEV(EVaddress), "403");
        require(contractInstance.isCS(CSaddress), "303");
        require(nonce != 0, "601");
        require(!contractInstance.isConnected(EVaddress, CSaddress), "602");

        Connection memory connection = contractInstance.getConnection(EVaddress, CSaddress);

        if ( connection.nonce == 0 ) {
            connection.nonce = nonce;
        }

        if ( tx.origin == EVaddress ) {
            // Check if connection is pending
            if ( connection.EVconnected && !connection.CSconnected && connection.nonce == nonce ) {
                revert("603");
            }

            // Change nonce
            if ( connection.EVconnected && !connection.CSconnected && connection.nonce != nonce ) {
                connection.nonce = nonce;
            }

            // Check that nonce is correct
            require(connection.nonce != nonce, "606");

            // Accept connection as EV
            connection.EV = EVaddress;
            connection.CS = CSaddress;
            connection.EVconnected = true;
            if ( connection.EVconnected && connection.CSconnected ) {
                connection.establishedDate = block.timestamp;
            }
        }
        else {
            // Check if connection is pending
            if ( connection.CSconnected && !connection.EVconnected && connection.nonce == nonce ) {
                revert("604");
            }

            // Change nonce 
            if ( connection.CSconnected && !connection.EVconnected && connection.nonce != nonce ) {
                connection.nonce = nonce;
            }

            // Check that nonce is correct
            require(connection.nonce != nonce, "606");

            // Accept connection as CS
            connection.EV = EVaddress;
            connection.CS = CSaddress;
            connection.CSconnected = true;
            if ( connection.EVconnected && connection.CSconnected ) {
                connection.establishedDate = block.timestamp;
            }
        }

        return connection;
    }

    function disconnect(address EVaddress, address CSaddress) public view returns (Connection memory) {
        require(msg.sender == contractAddress, "102");
        require(tx.origin == EVaddress || tx.origin == CSaddress, "402/302");
        require(contractInstance.isEV(EVaddress), "403");
        require(contractInstance.isCS(CSaddress), "303");

        Connection memory connection = contractInstance.getConnection(EVaddress, CSaddress);

        require(connection.EVconnected && connection.CSconnected, "605");

        Connection memory deleted;
        return deleted;
    }

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