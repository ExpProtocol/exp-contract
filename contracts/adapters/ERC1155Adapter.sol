// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../interfaces/IAdapter.sol";
import "hardhat/console.sol";

contract ERC1155Adapter is IAdapter {
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

  struct DataFormat {
    uint256 tokenId;
    uint256 amount;
  }

  function isValidData(bytes calldata data) external pure override returns (bool) {
    return data.length == 64;
  }

  function isBorrowable(
    address market,
    address lender,
    address token,
    bool isLocked,
    bytes calldata data
  ) external view returns (bool) {
    DataFormat memory tokenData = abi.decode(data, (DataFormat));

    if (isLocked) {
      return IERC1155(token).balanceOf(market, tokenData.tokenId) >= tokenData.amount;
    } else {
      return
        IERC1155(token).isApprovedForAll(lender, market) &&
        IERC1155(token).balanceOf(lender, tokenData.tokenId) >= tokenData.amount;
    }
  }

  function isReturnable(
    address market,
    address renter,
    address token,
    bytes calldata data
  ) external view returns (bool) {
    DataFormat memory tokenData = abi.decode(data, (DataFormat));
    return
      IERC1155(token).isApprovedForAll(renter, market) &&
      IERC1155(token).balanceOf(renter, tokenData.tokenId) >= tokenData.amount;
  }

  function logLend(
    uint96 lendId,
    address lender,
    address token,
    address payment,
    uint120 pricePerSec,
    uint120 totalPrice,
    bool autoReRegister,
    bytes calldata data // bytes memory data
  ) external {
    //require(msg.sender == market, "Not market");
    DataFormat memory tokenData = abi.decode(data, (DataFormat));
    emit ERC1155LendRegistered(
      lendId,
      lender,
      token,
      payment,
      tokenData.tokenId,
      tokenData.amount,
      pricePerSec,
      totalPrice,
      autoReRegister
    );
  }

  function lendTransfer(
    address market,
    address lender,
    address token,
    address renter,
    bool isLocked,
    bytes calldata data
  ) external {
    DataFormat memory tokenData = abi.decode(data, (DataFormat));
    if (isLocked) {
      IERC1155(token).safeTransferFrom(market, renter, tokenData.tokenId, tokenData.amount, "");
    } else {
      IERC1155(token).safeTransferFrom(lender, renter, tokenData.tokenId, tokenData.amount, "");
    }
  }

  function cancelLendTransfer(
    address market,
    address lender,
    address token,
    bool isLocked,
    bytes calldata data
  ) external {
    DataFormat memory tokenData = abi.decode(data, (DataFormat));
    if (isLocked) {
      IERC1155(token).safeTransferFrom(market, lender, tokenData.tokenId, tokenData.amount, "");
    }
  }

  function returnTransfer(
    address market,
    address lender,
    address token,
    address renter,
    bool,
    bool autoReRegister,
    bytes calldata data
  ) external returns (bool) {
    DataFormat memory tokenData = abi.decode(data, (DataFormat));
    if (autoReRegister) {
      IERC1155(token).safeTransferFrom(renter, market, tokenData.tokenId, tokenData.amount, "");
    } else {
      IERC1155(token).safeTransferFrom(renter, lender, tokenData.tokenId, tokenData.amount, "");
    }
    return autoReRegister;
  }
}
