// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./interfaces/IMarket.sol";
import "./adapters/ERC721Adapter.sol";
import "./adapters/ERC1155Adapter.sol";

contract Periphery {
  IMarket public market;
  ERC721Adapter public erc721Adaper;
  ERC1155Adapter public erc1155Adaper;

  constructor(address market_, address erc721Adaper_, address erc1155Adaper_) {
    market = IMarket(market_);
    erc721Adaper = ERC721Adapter(erc721Adaper_);
    erc1155Adaper = ERC1155Adapter(erc1155Adaper_);
  }

  function lend721(
    address token,
    uint256 tokenId,
    address payment,
    uint120 pricePerSec,
    uint120 totalPrice,
    bool autoReRegister
  ) external {
    market.registerToLend(
      erc721Adaper,
      token,
      payment,
      pricePerSec,
      totalPrice,
      autoReRegister,
      abi.encode(ERC721Adapter.DataFormat(tokenId))
    );
  }

  function lend1155(
    address token,
    uint256 tokenId,
    uint256 amount,
    address payment,
    uint120 pricePerSec,
    uint120 totalPrice,
    bool autoReRegister
  ) external {
    market.registerToLend(
      erc1155Adaper,
      token,
      payment,
      pricePerSec,
      totalPrice,
      autoReRegister,
      abi.encode(ERC1155Adapter.DataFormat(tokenId, amount))
    );
  }
}
