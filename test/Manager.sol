// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./Params.sol";

contract Manager is Params, IManager {

    bool valid;
    ImportantData data;

    address worker;
    IWork workInstance;

    function setWorker(address workerAddress) public {
        worker = workerAddress;
        workInstance = IWork(workerAddress);
    }

    function setValid(bool _valid) public {
        valid = _valid;
    }

    function isValid() external view returns (bool) {
        return valid;
    }

    function update() public {
        data = workInstance.processImportantData(data);
    }

    function get() public view returns (ImportantData memory) {
        return data;
    }

}