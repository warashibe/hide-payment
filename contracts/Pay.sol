//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.0;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712MetaTransaction} from "./EIP712MetaTransaction.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract Pay is Ownable, EIP712MetaTransaction("Pay", "4")  {
  address public token;
  address public payback_token;
  address public payback_owner;

  uint public minAmount = 10 ** 18;
  uint public minPayback = 10 ** 18;
  uint public minFee = 10 ** 18;
  uint public fee;

  mapping(address => bool) public exchanges;
  
  event Payment(address indexed from, address indexed to, address indexed from_token, address to_token, uint from_amount, uint to_amount, uint fee, string ref, uint payback);
  
  constructor(uint _fee, address _token, address _payback_token, address _payback_owner) public {
    require(_fee <= 10000, "fee must be less than or equal to 10000");
    fee = _fee;
    token = _token;
    payback_token = _payback_token;
    payback_owner = _payback_owner;
  }
  
  function getAmountsOut(uint _value, address[] memory path, address _swap)
    internal
    view
    returns (uint[] memory)
  {
    return IUniswapV2Router02(_swap).getAmountsOut(_value, path);
  }
  
  function getAmountsIn(uint _value, address[] memory path, address _swap)
    internal
    view
    returns (uint[] memory)
  {
    return IUniswapV2Router02(_swap).getAmountsIn(_value, path);
  }
  
  function _payback (uint amount) internal {
    IERC20(payback_token).transferFrom(payback_owner, msgSender(), amount);
  }
  
  function _calcFees(uint amount, uint payback) internal view returns(uint tx_fee, uint payback_amount){
    require(payback <= 10000, "payback must be equal to or less than 10000");
    require(minAmount < amount, "amount too small");
    payback_amount = amount.mul(payback).div(10000);
    if(payback_amount < minPayback) payback_amount = minPayback;
    uint base_tx_fee = amount.mul(fee).div(10000);
    if(base_tx_fee < minFee) base_tx_fee = minFee;
    tx_fee = base_tx_fee > payback_amount ? base_tx_fee : payback_amount;
    if(tx_fee > amount) tx_fee = amount;
  }
  
  function _pay(address to, uint amount, uint from_amount, string memory ref, address _token, uint payback) internal {
    (uint tx_fee, uint payback_amount) = _calcFees(amount, payback);
    IERC20(token).transfer(owner(), tx_fee);
    IERC20(token).transfer(to, amount.sub(tx_fee));
    emit Payment(msgSender(), to, _token, token, from_amount, amount, tx_fee, ref, payback_amount);
    _payback(payback_amount);
  }

  function _checkParams(address[] memory _tokens, address swap) internal view {
    require(exchanges[swap] == true, "exchange not allowed");
    require(_tokens[_tokens.length - 1] == token, "last token must be JPYC");
  }
  
  function _transferERC20(uint[] memory amounts, address[] memory _tokens, address swap) internal {
    require(minAmount < amounts[amounts.length - 1], "amount too small");
    IERC20(_tokens[0]).transferFrom(msgSender(), address(this), amounts[0]);
    IERC20(_tokens[0]).approve(swap, amounts[0]);
  }
  
  function _checkAmountsETH(uint[] memory amounts) internal view {
    require(minAmount < amounts[amounts.length - 1], "amount too small");
    require(msg.value >= amounts[0], "msg.value too small");
  }
  
  function _sendBackDiff(uint[] memory _amounts) internal {
    uint diff = msg.value - _amounts[0];
    if(diff > 0) msg.sender.transfer(diff);
  }

  function pay(address to, uint amount, string memory ref, uint payback) public {
    (uint tx_fee, uint payback_amount) = _calcFees(amount, payback);
    IERC20(token).transferFrom(msgSender(), owner(), tx_fee);
    IERC20(token).transferFrom(msgSender(), to, amount.sub(tx_fee));
    emit Payment(msgSender(), to, token, token, amount, amount, tx_fee, ref, payback_amount);
    _payback(payback_amount);
  }
  
  function swapAndPayExactIn(address to, address[] memory _tokens, uint amount, string memory ref, uint min, uint deadline, address swap, uint payback) public {
    _checkParams(_tokens, swap);
    uint[] memory amounts = getAmountsOut(amount, _tokens, swap);
    _transferERC20(amounts, _tokens, swap);
    uint[] memory _amounts = IUniswapV2Router02(swap).swapExactTokensForTokens(amounts[0], min, _tokens, address(this), deadline);
    _pay(to,_amounts[_amounts.length - 1], _amounts[0], ref, _tokens[0], payback);
  }

  function swapAndPayExactOut(address to, address[] memory _tokens, uint amount, string memory ref, uint max, uint deadline, address swap, uint payback) public {
    _checkParams(_tokens, swap);
    uint[] memory amounts = getAmountsIn(amount, _tokens, swap);
    _transferERC20(amounts, _tokens, swap);
    uint[] memory _amounts = IUniswapV2Router02(swap).swapTokensForExactTokens(amount, max, _tokens, address(this), deadline);
    _pay(to,_amounts[_amounts.length - 1], _amounts[0], ref, _tokens[0], payback);
  }

  function swapAndPayExactInETH(address to, address[] memory _tokens, string memory ref, uint min, uint deadline, address swap, uint payback) public payable{
    _checkParams(_tokens, swap);
    uint[] memory amounts = getAmountsOut(msg.value, _tokens, swap);
    _checkAmountsETH(amounts);
    uint[] memory _amounts = IUniswapV2Router02(swap).swapExactETHForTokens{value:amounts[0]}( min, _tokens, address(this), deadline);
    _sendBackDiff(_amounts);
    _pay(to,_amounts[_amounts.length - 1], _amounts[0], ref, _tokens[0], payback);
  }

  function swapAndPayExactOutETH(address to, address[] memory _tokens, uint amount, string memory ref, uint deadline, address swap, uint payback) public payable{
    _checkParams(_tokens, swap);
    uint[] memory amounts = getAmountsIn(amount, _tokens, swap);
    _checkAmountsETH(amounts);
    uint[] memory _amounts = IUniswapV2Router02(swap).swapETHForExactTokens{value:amounts[0]}(amounts[1], _tokens, address(this), deadline);
    _sendBackDiff(_amounts);
    _pay(to,_amounts[_amounts.length - 1], _amounts[0], ref, _tokens[0], payback);
  }
  
  function addExchange(address _address) public onlyOwner {
    exchanges[_address] = true;
  }
  
  function removeExchange(address _address) public onlyOwner {
    exchanges[_address] = false;
  }
  
  function setMinAmount(uint _int) public onlyOwner {
    minAmount = _int;
  }
  
  function setMinFee(uint _int) public onlyOwner {
    minFee = _int;
  }
  
  function setMinPayback(uint _int) public onlyOwner {
    minPayback = _int;
  }

  function setFee(uint _int) public onlyOwner {
    fee = _int;
  }
  
}
