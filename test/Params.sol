// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface Params {
    struct ImportantData {
        uint number;
        string message;
    }
}

interface IWork is Params {
    function processImportantData(ImportantData memory data) external returns (ImportantData memory);
}

interface IManager is Params {
    function isValid() external view returns (bool);
}