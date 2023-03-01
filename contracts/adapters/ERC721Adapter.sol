// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../interfaces/IAdapter.sol";

contract ERC721Adapter is IAdapter {
  struct DataFormat {
    uint256 tokenId;
  }

  function isValidData(bytes calldata) external pure override returns (bool) {
    return true;
  }

  function isBorrowable(
    address market,
    address,
    address token,
    bytes calldata data
  ) external view returns (bool) {
    uint256 tokenId = abi.decode(data, (uint256));
    return
      IERC721(token).getApproved(tokenId) == market ||
      IERC721(token).ownerOf(tokenId) == market;
  }

  function isReturnable(
    address market,
    address,
    address token,
    bytes calldata data
  ) external view returns (bool) {
    uint256 tokenId = abi.decode(data, (uint256));
    return IERC721(token).getApproved(tokenId) == market;
  }

  function lendTransfer(
    address market,
    address lender,
    address token,
    address renter,
    bytes calldata data
  ) external {
    uint256 tokenId = abi.decode(data, (uint256));
    if (IERC721(token).ownerOf(tokenId) == lender) {
      IERC721(token).safeTransferFrom(lender, renter, tokenId);
    } else {
      IERC721(token).safeTransferFrom(market, renter, tokenId);
    }
  }

  function cancelLendTransfer(
    address market,
    address lender,
    address token,
    bytes calldata data
  ) external {
    uint256 tokenId = abi.decode(data, (uint256));
    if (IERC721(token).ownerOf(tokenId) == market) {
      IERC721(token).safeTransferFrom(market, lender, tokenId);
    }
  }

  function returnTransfer(
    address market,
    address lender,
    address token,
    address renter,
    bool autoReRegister,
    bytes calldata data
  ) external {
    uint256 tokenId = abi.decode(data, (uint256));
    if (autoReRegister) {
      IERC721(token).safeTransferFrom(renter, market, tokenId);
    } else {
      IERC721(token).safeTransferFrom(renter, lender, tokenId);
    }
  }
}
