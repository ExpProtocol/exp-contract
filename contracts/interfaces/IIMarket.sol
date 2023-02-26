// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IAdapter.sol";

interface IMarket {
  struct Lend {
    address lender;
    IAdapter adapter;
    address token;
    IERC20 payment;
    uint120 pricePerSec;
    uint120 totalPrice;
    bool autoReRegister;
    bytes data;
  }
  struct RentContract {
    address renter;
    uint96 startTime;
    address guarantor;
    uint120 balance;
    uint120 guarantBalance;
    uint16 guarantFee;
  }

  function rent(uint96 lendId) external;

  function rentWithGuarantor(
    uint96 lendId,
    address guarantor,
    uint120 guarantBalance,
    uint16 guarantFee,
    bytes calldata signature
  ) external;

  function returnToken(uint96 lendId) external;

  function claim(uint96 lendId) external;

  function unlockToken(uint96 lendId) external;

  function registerToLend(
    address adapter,
    address token,
    address payment,
    uint120 pricePerSec,
    uint120 totalPrice,
    bool autoReRegister,
    bytes calldata data
  ) external;

  function renewalLend(
    uint96 lendId,
    address payment,
    uint120 pricePerSec,
    uint120 totalPrice,
    bool autoReRegister,
    bytes calldata data
  ) external;

  function cancelLend(uint96 lendId) external;

  function isBorrowable(uint96 lendId) external view returns (bool);

  function lendCondition(
    uint96 lendId
  )
    external
    view
    returns (
      address lender,
      address adapter,
      address token,
      address payment,
      uint120 pricePerSec,
      uint120 totalPrice,
      bool autoReRegister,
      bytes calldata data
    );

  function rentCondition(
    uint96 lendId
  )
    external
    view
    returns (
      address payment,
      uint120 pricePerSec,
      uint120 totalPrice,
      bool autoReRegister,
      bytes calldata data
    );
}
