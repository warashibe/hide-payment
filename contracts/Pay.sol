//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.0;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712MetaTransaction} from "./EIP712MetaTransaction.sol";

contract Pay is Ownable, EIP712MetaTransaction("Pay", "1")  {
  uint256 fee;
  mapping(address => bool) public tokens;
  mapping(address => uint256) public minAmounts;
  mapping(address => uint256) public minFees;
  
  event Payment(address indexed from, address indexed to, address indexed token, uint256 amount, uint256 fee, string ref);
  
  constructor(uint256 _fee) public {
    require(_fee <= 10000, "fee must be less than or equal to 10000");
    fee = _fee;
  }

  function payERC20(address to, address token, uint256 amount, string memory ref) public {
    require(tokens[token] == true, "token not allowed");
    require(minAmounts[token] <= amount, "amount too small");
    uint256 tx_fee = amount.mul(fee).div(10000);
    if(tx_fee < minFees[token]) tx_fee = minFees[token];
    IERC20(token).transferFrom(msgSender(), owner(), tx_fee);
    IERC20(token).transferFrom(msgSender(), to, amount.sub(tx_fee));
    emit Payment(msgSender(), to, token, amount, tx_fee, ref);
  }
  
  function setFee(uint256 _fee) public onlyOwner {
    fee = _fee;
  }
  
  function addToken(address _token, uint256 _amount, uint256 _fee) public onlyOwner {
    require(_amount >= _fee, "minAmount must be greater than or equal to minFee");
    tokens[_token] = true;
    minAmounts[_token] = _amount;
    minFees[_token] = _fee;
  }
  
  function removeToken(address _token) public onlyOwner {
    tokens[_token] = false;
  }
}
