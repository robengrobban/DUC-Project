// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./Params.sol";

contract Work is Params, IWork {

    uint calls;

    address manager;
    IManager managerInstance;

    function setManager(address managerAddress) public {
        manager = managerAddress;
        managerInstance = IManager(managerAddress);
    }

    function processImportantData(ImportantData memory data) external returns (ImportantData memory) {
        calls++;
        if (managerInstance.isValid()) {
            data.number += 1;
            data.message = string.concat(data.message, "a");
        }
        return data;
    }

    function numCalls() public view returns (uint) {
        return calls;
    }

}