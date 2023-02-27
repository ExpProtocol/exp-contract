// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IIMarket.sol";
import "./interfaces/IAdapter.sol";

contract Market is IMarket, Context, EIP712 {
  uint96 private _totalLend;
  mapping(uint96 => Lend) public lends;
  mapping(uint96 => RentContract) public rentContracts;
  mapping(address => uint24) public usedNonces;

  bytes32 constant GUARANT_REQUEST_TYPE_HASH =
    keccak256(
      abi.encodePacked(
        "GuarantRequest(",
        "uint96 lendId,",
        "uint120 guarantBalance,",
        "uint16 guarantFee,",
        "uint24 nonce"
        ")"
      )
    );

  constructor() EIP712("EXP-Market", "1") {}

  function _blockTimeStamp() private returns (uint96) {
    return uint96(block.timestamp);
  }

  function rent(uint96 lendId) public {
    Lend memory lend = lends[lendId];
    require(lend.lender != address(0), "Lend not found");
    require(rentContracts[lendId].renter == address(0), "Already rented");
    require(
      lend.adapter.isBorrowable(_msgSender(), lend.token, lend.data),
      "Not borrowable"
    );
    lend.payment.transferFrom(_msgSender(), lend.lender, lend.totalPrice);
    lend.adapter.lendTransfer(lend.lender, lend.token, _msgSender(), lend.data);
    rentContracts[lendId] = RentContract({
      renter: _msgSender(),
      startTime: _blockTimeStamp(),
      guarantor: address(0),
      balance: lend.totalPrice,
      guarantBalance: 0,
      guarantFee: 0
    });
  }

  function rentWithGuarantor(
    uint96 lendId,
    address guarantor,
    uint120 guarantBalance,
    uint16 guarantFee,
    bytes calldata signature
  ) public {
    Lend memory lend = lends[lendId];
    require(lend.lender != address(0), "Lend not found");
    require(rentContracts[lendId].renter == address(0), "Already rented");
    require(
      lend.adapter.isBorrowable(_msgSender(), lend.token, lend.data),
      "Not borrowable"
    );

    bytes32 guarantDigest = _hashTypedDataV4(
      keccak256(
        abi.encode(
          GUARANT_REQUEST_TYPE_HASH,
          lendId,
          guarantBalance,
          guarantFee,
          usedNonces[guarantor] + 1
        )
      )
    );

    require(
      ECDSA.recover(guarantDigest, signature) == guarantor,
      "Invalid signature"
    );

    lend.payment.transferFrom(
      _msgSender(),
      lend.lender,
      lend.totalPrice - guarantBalance
    );
    lend.payment.transferFrom(guarantor, lend.lender, guarantBalance);

    lend.adapter.lendTransfer(lend.lender, lend.token, _msgSender(), lend.data);
    rentContracts[lendId] = RentContract({
      renter: _msgSender(),
      startTime: _blockTimeStamp(),
      guarantor: address(0),
      balance: lend.totalPrice,
      guarantBalance: 0,
      guarantFee: 0
    });

    usedNonces[guarantor]++;
  }

  function registerToLend(
    IAdapter adapter,
    address token,
    address payment,
    uint120 pricePerSec,
    uint120 totalPrice,
    bool autoReRegister,
    bytes calldata data
  ) public {
    require(adapter.isValidData(data), "Invalid data");
    require(adapter.isBorrowable(_msgSender(), token, data), "Not borrowable");
    lends[_totalLend] = Lend({
      lender: _msgSender(),
      adapter: IAdapter(adapter),
      token: token,
      payment: IERC20(payment),
      pricePerSec: pricePerSec,
      totalPrice: totalPrice,
      autoReRegister: autoReRegister,
      data: data
    });
    _totalLend++;
  }
}
