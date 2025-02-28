// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IPancakeRouter.sol";  // PancakeSwap interface

contract WebhookTrader is Ownable, ReentrancyGuard {
    IPancakeRouter public pancakeRouter;
    address public WBNB;
    address public tradeToken;
    uint256 public maxGas;
    uint256 public slippage;

    event TradeExecuted(string tradeType, uint256 amount, uint256 price, uint256 gasUsed);

    constructor(address _router, address _WBNB, address _tradeToken) {
        pancakeRouter = IPancakeRouter(_router);
        WBNB = _WBNB;
        tradeToken = _tradeToken;
        maxGas = 500000;
        slippage = 2;
    }

    modifier ensureGasLimit() {
        require(gasleft() <= maxGas, "Gas limit exceeded");
        _;
    }

    modifier onlyWebhook() {
        require(msg.sender == owner(), "Unauthorized Webhook Access");
        _;
    }

    // Deposit BNB into contract
    function depositBNB() external payable onlyOwner {}

    // Deposit Tokens into contract
    function depositTokens(uint256 amount) external onlyOwner {
        require(IERC20(tradeToken).transferFrom(msg.sender, address(this), amount), "Token transfer failed");
    }

    // Buy tokens using BNB in contract
    function buy(uint256 amountInBNB) external onlyWebhook ensureGasLimit nonReentrant {
        require(address(this).balance >= amountInBNB, "Insufficient BNB balance");

        address;
        path[0] = WBNB;
        path[1] = tradeToken;

        uint256 minAmountOut = getMinAmountOut(amountInBNB, path);

        pancakeRouter.swapExactETHForTokens{value: amountInBNB}(
            minAmountOut,
            path,
            address(this),
            block.timestamp + 300
        );

        emit TradeExecuted("BUY", amountInBNB, minAmountOut, gasleft());
    }

    // Sell tokens for BNB
    function sell(uint256 amountInTokens) external onlyWebhook ensureGasLimit nonReentrant {
        require(IERC20(tradeToken).balanceOf(address(this)) >= amountInTokens, "Insufficient token balance");

        IERC20(tradeToken).approve(address(pancakeRouter), amountInTokens);

        address;
        path[0] = tradeToken;
        path[1] = WBNB;

        uint256 minAmountOut = getMinAmountOut(amountInTokens, path);

        pancakeRouter.swapExactTokensForETH(
            amountInTokens,
            minAmountOut,
            path,
            address(this),
            block.timestamp + 300
        );

        emit TradeExecuted("SELL", amountInTokens, minAmountOut, gasleft());
    }

    // Calculate minimum output considering slippage
    function getMinAmountOut(uint256 amountIn, address[] memory path) public view returns (uint256) {
        uint256[] memory amountsOut = pancakeRouter.getAmountsOut(amountIn, path);
        return amountsOut[1] - ((amountsOut[1] * slippage) / 100);
    }

    // Set trade token
    function setTradeToken(address _tradeToken) external onlyOwner {
        tradeToken = _tradeToken;
    }

    // Set maximum gas per transaction
    function setMaxGas(uint256 _maxGas) external onlyOwner {
        maxGas = _maxGas;
    }

    // Set slippage tolerance
    function setSlippage(uint256 _slippage) external onlyOwner {
        require(_slippage <= 10, "Slippage too high");
        slippage = _slippage;
    }

    // Withdraw tokens from contract
    function withdrawTokens(address token) external onlyOwner {
        IERC20 erc20Token = IERC20(token);
        erc20Token.transfer(owner(), erc20Token.balanceOf(address(this)));
    }

    // Withdraw BNB from contract
    function withdrawBNB() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {}
}
