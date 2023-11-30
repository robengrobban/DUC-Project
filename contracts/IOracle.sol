// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';

interface IOracle is Structure {

    function addValidRegion(bytes3 region) external;
    function automaticRate(Rate memory) external returns (Rate memory);

}