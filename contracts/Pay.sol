//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.0;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712MetaTransaction} from "./EIP712MetaTransaction.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract Pay is Ownable, EIP712MetaTransaction("Pay", "2")  {
  uint public fee;
  address public token;
  mapping(address => bool) public exchanges; 
  uint public minAmount = 10 ** 18;
  uint public minFee = 10 ** 18;
  
  event Payment(address indexed from, address indexed to, address indexed from_token, address to_token, uint from_amount, uint to_amount, uint fee, string ref);
  
  constructor(uint _fee, address _token) public {
    require(_fee <= 10000, "fee must be less than or equal to 10000");
    fee = _fee;
    token = _token;
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

  function _pay(address to, uint amount, uint from_amount, string memory ref, address _token) internal {
    uint tx_fee = amount.mul(fee).div(10000);
    if(tx_fee < minFee) tx_fee = minFee;
    IERC20(token).transfer(owner(), tx_fee);
    IERC20(token).transfer(to, amount.sub(tx_fee));
    emit Payment(msgSender(), to, _token, token, from_amount, amount, tx_fee, ref);
  }
  
  function pay(address to, uint amount, string memory ref) public {
    require(minAmount <= amount, "amount too small");
    uint tx_fee = amount.mul(fee).div(10000);
    if(tx_fee < minFee) tx_fee = minFee;
    IERC20(token).transferFrom(msgSender(), owner(), tx_fee);
    IERC20(token).transferFrom(msgSender(), to, amount.sub(tx_fee));
    emit Payment(msgSender(), to, token, token, amount, amount, tx_fee, ref);
  }
  
  function swapAndPayExactIn(address to, address[] memory _tokens, uint amount, string memory ref, uint min, uint deadline, address swap) public {
    require(exchanges[swap] == true, "exchange not allowed");
    require(_tokens[_tokens.length - 1] == token, "last token must be JPYC");
    uint[] memory amounts = getAmountsOut(amount, _tokens, swap);
    require(minAmount <= amounts[amounts.length - 1], "amount too small");
    IERC20(_tokens[0]).transferFrom(msgSender(), address(this), amounts[0]);
    IERC20(_tokens[0]).approve(swap, amounts[0]);
    uint[] memory _amounts = IUniswapV2Router02(swap).swapExactTokensForTokens(amounts[0], min, _tokens, address(this), deadline);
    _pay(to,_amounts[_amounts.length - 1], _amounts[0], ref, _tokens[0]);
  }

  function swapAndPayExactOut(address to, address[] memory _tokens, uint amount, string memory ref, uint max, uint deadline, address swap) public {
    require(exchanges[swap] == true, "exchange not allowed");
    require(_tokens[_tokens.length - 1] == token, "last token must be JPYC");
    uint[] memory amounts = getAmountsIn(amount, _tokens, swap);
    require(minAmount <= amounts[amounts.length - 1], "amount too small");
    IERC20(_tokens[0]).transferFrom(msgSender(), address(this), amounts[0]);
    IERC20(_tokens[0]).approve(swap, amounts[0]);
    uint[] memory _amounts = IUniswapV2Router02(swap).swapTokensForExactTokens(amount, max, _tokens, address(this), deadline);
    _pay(to,_amounts[_amounts.length - 1], _amounts[0], ref, _tokens[0]);
  }

  function setFee(uint _fee) public onlyOwner {
    fee = _fee;
  }
  
  function addExchange(address _address) public onlyOwner {
    exchanges[_address] = true;
  }
  
  function removeExchange(address _address) public onlyOwner {
    exchanges[_address] = false;
  }
  
  function setMinAmount(uint _min) public onlyOwner {
    minAmount = _min;
  }
  
  function setMinFee(uint _fee) public onlyOwner {
    minFee = _fee;
  }
  
}
