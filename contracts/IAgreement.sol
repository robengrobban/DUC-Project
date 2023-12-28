// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import './Structure.sol';

interface IAgreement is Structure {

    function proposeAgreement(address, address, AgreementParameters calldata) external returns (Agreement memory);
    function revertProposedAgreement(address, address, uint) external view returns (Agreement memory);
    function respondAgreement(address, address, bool, uint) external view returns (Agreement memory);
    
}