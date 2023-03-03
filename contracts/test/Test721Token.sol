// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Test721Token is ERC721 {
  constructor() ERC721("TST721", "TST721") {}

  function mint(address account, uint256 id) public {
    _mint(account, id);
  }
}
