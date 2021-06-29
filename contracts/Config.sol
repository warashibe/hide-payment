//SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Config is Ownable  {
  uint public totalWP;
  mapping(address => uint) public earnings;
  mapping(address => uint) public paybacks;
  
  constructor() public {}

  function recordWP(address from, address to, uint amount) external {
    earnings[from] += amount;
    paybacks[to] += amount;
    totalWP += amount;
  }

  function setTotalWP(uint amount) external {
    totalWP = amount;
  }
  
  function bulkRecordWP(address[] memory from, address[] memory to, uint[] memory _earnings, uint[] memory _paybacks) public onlyOwner {
    require(from.length == _earnings.length && to.length == _paybacks.length, "array lengths must be the same");
    for(uint i = 0;i < from.length;i++){
      earnings[from[i]] = _earnings[i];
    }
    for(uint i = 0;i < to.length;i++){
      paybacks[to[i]] = _paybacks[i];
    }
  }

}
