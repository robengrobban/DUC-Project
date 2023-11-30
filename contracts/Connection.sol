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
            if ( connection.nonce != nonce ) {
                revert("606");
            }

            // Accept connection as EV
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
            if ( connection.nonce != nonce ) {
                revert("606");
            }

            // Accept connection as CS
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
        require(connection.EVconnected || connection.CSconnected, "605");

        Connection memory deleted;
        return deleted;
    }

    /*
    * LIBRARY FUNCTIONS
    */

    

}