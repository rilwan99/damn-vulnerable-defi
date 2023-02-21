// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {encodePriceSqrt} from "./Math.sol";

contract PlayerContract is IUniswapV3SwapCallback {
    uint32 public constant TWAP_PERIOD = 10 minutes;

    address uniswapV3Pool;
    IERC20Minimal public immutable token;
    address public weth;

    constructor(address _uniswapV3Pool, address _token, address _weth) {
        uniswapV3Pool = _uniswapV3Pool;
        token = IERC20Minimal(_token);
        weth = _weth;
    }

    function getArithmeticTick() public view returns (int24) {
        (int24 arithmeticMeanTick, ) = OracleLibrary.consult(
            address(uniswapV3Pool),
            TWAP_PERIOD
        );
        return arithmeticMeanTick;
    }

    function getQuote() public returns (uint256) {
        uint256 quoteAmount = OracleLibrary.getQuoteAtTick(
            getArithmeticTick(),
            1000000 ether, // baseAmount
            address(token), // baseToken
            address(weth) // quoteToken
        );
        return quoteAmount;
    }

    function getSlot0() public returns (uint160) {
        (uint160 _sqrtPriceX96, , , , , , ) = IUniswapV3Pool(uniswapV3Pool)
            .slot0();
        return _sqrtPriceX96;
    }

    function executeSwap() public returns (int256, int256) {
        int256 amountSpecified = -int256(token.balanceOf(address(this)));
        uint160 sqrtPriceLimitX96 = encodePriceSqrt(2, 1);

        (int256 amount0, int256 amount1) = IUniswapV3Pool(uniswapV3Pool).swap(
            address(this),
            false, // zeroForOne
            amountSpecified,
            sqrtPriceLimitX96,
            "0x" // calldata
        );
        return (amount0, amount1);
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) public override {
        token.transfer(msg.sender, uint256(amount1Delta));
    }
}
