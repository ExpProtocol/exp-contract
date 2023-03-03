// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/IAccessControlEnumerable.sol";
import "./IAdapter.sol";
import "./IAdapter.sol";

interface IMarket is IAccessControlEnumerable {
  struct Lend {
    address lender;
    IAdapter adapter;
    address token;
    IERC20 payment;
    uint120 pricePerSec;
    uint120 totalPrice;
    bool isLocked;
    bool autoReRegister;
    bytes data;
  }
  struct RentContract {
    address renter;
    uint96 startTime;
    address guarantor;
    uint120 guarantBalance;
    uint16 guarantFee; // (1/x)%
  }

  event LendRegistered(
    uint96 indexed lendId,
    address indexed lender,
    address adapter,
    address token,
    address payment,
    uint120 pricePerSec,
    uint120 totalPrice,
    bool autoReRegister,
    bytes data
  );

  event RentStarted(
    uint96 indexed lendId,
    address indexed renter,
    address indexed guarantor,
    uint120 guarantBalance,
    uint16 guarantFee
  );

  event RentReturned(uint96 indexed lendId, address indexed renter);

  event MinimumRentTimeUpdated(
    uint96 oldMinimumRentTime,
    uint96 newMinimumRentTime
  );

  event LendCanceled(uint96 indexed lendId, address indexed lender);

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

  function registerToLend(
    IAdapter adapter,
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

  function usedNonces(address) external view returns (uint24);

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
      bytes memory data
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
      bytes memory data
    );
}
