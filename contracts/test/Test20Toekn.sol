// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Test20Token is ERC20 {
  constructor() ERC20("TST20", "TST20") {}

  function mint(address account, uint256 amount) public {
    _mint(account, amount);
  }
}
