// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../interfaces/IAdapter.sol";

contract ERC721Adapter is IAdapter {
  struct DataFormat {
    uint256 tokenId;
  }

  function isValidData(
    bytes calldata data
  ) external pure override returns (bool) {}

  function isBorrowable(
    address,
    address token,
    bytes calldata data
  ) external view override returns (bool) {
    uint256 tokenId = abi.decode(data, (uint256));
    return
      IERC721(token).getApproved(tokenId) == msg.sender ||
      IERC721(token).ownerOf(tokenId) == msg.sender;
  }

  function lendTransfer(
    address lender,
    address token,
    address renter,
    bytes calldata data
  ) external {
    uint256 tokenId = abi.decode(data, (uint256));
    IERC721(token).safeTransferFrom(lender, renter, tokenId);
  }
}
