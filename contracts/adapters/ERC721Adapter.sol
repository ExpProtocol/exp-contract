// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../interfaces/IAdapter.sol";

contract ERC721Adapter is IAdapter {
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

  function logLend(
    uint96 lendId,
    address market,
    address lender,
    address token,
    address payment,
    uint120 pricePerSec,
    uint120 totalPrice,
    bool autoReRegister,
    bytes memory data
  ) external {
    require(msg.sender == market, "Not market");
    uint256 tokenId = abi.decode(data, (uint256));
    emit ERC721LendRegistered(
      lendId,
      lender,
      token,
      payment,
      tokenId,
      pricePerSec,
      totalPrice,
      autoReRegister
    );
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
