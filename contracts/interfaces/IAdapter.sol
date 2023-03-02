// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IAdapter {
  function isValidData(bytes calldata data) external view returns (bool);

  function isBorrowable(
    address market,
    address lender,
    address token,
    bytes calldata data
  ) external view returns (bool);

  function isReturnable(
    address market,
    address renter,
    address token,
    bytes calldata data
  ) external view returns (bool);

  function logLend(
    uint96 lendId,
    address market,
    //bytes32 lendIdAndMarket, //Optimize plan
    address lender,
    address token,
    address payment,
    uint120 pricePerSec,
    uint120 totalPrice,
    bool autoReRegister,
    bytes memory data
  ) external;

  function lendTransfer(
    address market,
    address lender,
    address token,
    address renter,
    bytes calldata data
  ) external;

  function cancelLendTransfer(
    address market,
    address lender,
    address token,
    bytes calldata data
  ) external;

  function returnTransfer(
    address market,
    address lender,
    address token,
    address renter,
    bool autoReRegister,
    bytes calldata data
  ) external;
}
