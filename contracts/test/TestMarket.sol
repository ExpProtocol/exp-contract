// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../Market.sol";

contract TestMarket is Market {
  event ERC721LendRegistered(
    uint96 indexed lendId,
    address indexed lender,
    address indexed token,
    address payment,
    uint256 tokenId,
    uint120 pricePerSec,
    uint120 totalPrice,
    bool autoReRegister
  );

  event ERC1155LendRegistered(
    uint96 indexed lendId,
    address indexed lender,
    address indexed token,
    address payment,
    uint256 tokenId,
    uint256 amount,
    uint120 pricePerSec,
    uint120 totalPrice,
    bool autoReRegister
  );

  constructor(
    address receiver_,
    address erc721Adapter_,
    address erc1155Adapter_
  ) Market(receiver_, erc721Adapter_, erc1155Adapter_) {}
}
