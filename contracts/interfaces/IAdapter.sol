// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IAdapter {
  function isValidData(bytes calldata data) external view returns (bool);

  function isBorrowable(
    address lender,
    address token,
    bytes calldata data
  ) external view returns (bool);

  function lendTransfer(
    address lender,
    address token,
    address renter,
    bytes calldata data
  ) external;
}
