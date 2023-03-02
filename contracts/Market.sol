// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "./interfaces/IIMarket.sol";
import "./interfaces/IAdapter.sol";
import "./libraries/AdapterCaller.sol";
import "./libraries/FeeManager.sol";

contract Market is IMarket, AccessControlEnumerable, EIP712, FeeManager {
  uint96 private _totalLend;
  uint96 public minimalRentTime = 86400; // 1 day

  mapping(uint96 => Lend) public lends;
  mapping(uint96 => RentContract) public rentContracts;
  mapping(address => uint24) public usedNonces;

  bytes32 constant PROTOCOL_OWNER_ROLE = keccak256("PROTOCOL_OWNER_ROLE");

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

  constructor() EIP712("EXP-Market", "1") {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(PROTOCOL_OWNER_ROLE, _msgSender());
    _setupRole(TREASURY_ROLE, _msgSender());
  }

  function _blockTimeStamp() private view returns (uint96) {
    return uint96(block.timestamp);
  }

  function _isBorrowabe(Lend memory lend) private view returns (bool) {
    return
      lend.adapter.isBorrowable(
        address(this),
        _msgSender(),
        lend.token,
        lend.data
      );
  }

  function _isReturnable(uint96 lendId) private view returns (bool) {
    Lend memory lend = lends[lendId];
    RentContract memory rentContract = rentContracts[lendId];
    return
      lend.adapter.isReturnable(
        address(this),
        _msgSender(),
        lend.token,
        lend.data
      ) && rentContract.renter == _msgSender();
  }

  function returnToken(uint96 lendId) public {
    Lend memory lend = lends[lendId];
    RentContract memory rentContract = rentContracts[lendId];
    uint96 rentTime = _blockTimeStamp() - rentContract.startTime;
    uint120 rentFee = rentTime * lend.pricePerSec;
    require(rentContract.renter == _msgSender(), "Not renter");
    require(lend.totalPrice > rentFee, "Already overtime");
    require(_isReturnable(lendId), "Not returnable");

    AdapterCaller.returnTransfer(
      lend.adapter,
      address(this),
      lend.lender,
      lend.token,
      _msgSender(),
      lend.autoReRegister,
      lend.data
    );

    uint120 totalReturn = lend.totalPrice - rentFee;
    uint120 shoudReturnForGuarant = rentContract.guarantBalance +
      rentContract.guarantBalance /
      rentContract.guarantFee;
    if (shoudReturnForGuarant > totalReturn) {
      IERC20(lend.payment).transfer(rentContract.guarantor, totalReturn);
    } else {
      IERC20(lend.payment).transfer(
        rentContract.guarantor,
        shoudReturnForGuarant
      );
      IERC20(lend.payment).transfer(
        rentContract.renter,
        totalReturn - shoudReturnForGuarant
      );
    }

    uint256 lenderEarn = lend.totalPrice > rentFee ? rentFee : lend.totalPrice;
    uint256 fee = _collectFee(lend.payment, lenderEarn);
    IERC20(lend.payment).transfer(lend.lender, lenderEarn - fee);

    emit RentReturned(lendId, _msgSender());

    delete rentContracts[lendId];
  }

  function claim(uint96 lendId) public {
    Lend memory lend = lends[lendId];
    RentContract memory rentContract = rentContracts[lendId];
    uint96 rentTime = _blockTimeStamp() - rentContract.startTime;
    uint120 rentFee = rentTime * lend.pricePerSec;
    require(lend.lender == _msgSender(), "Not lender");
    require(rentFee > lend.totalPrice, "Not overtime");

    uint256 totalPrice = lend.totalPrice;
    uint256 fee = _collectFee(lend.payment, totalPrice);
    IERC20(lend.payment).transfer(lend.lender, totalPrice - fee);

    delete rentContracts[lendId];
    delete lends[lendId];
  }

  function _rent(uint96 lendId, Lend memory lend) private {
    AdapterCaller.lendTransfer(
      lend.adapter,
      address(this),
      lend.lender,
      lend.token,
      _msgSender(),
      lend.data
    );

    rentContracts[lendId] = RentContract({
      renter: _msgSender(),
      startTime: _blockTimeStamp(),
      guarantor: address(0),
      guarantBalance: 0,
      guarantFee: 0
    });
  }

  function rent(uint96 lendId) external {
    Lend memory lend = lends[lendId];
    require(lend.lender != address(0), "Lend not found");
    require(rentContracts[lendId].renter == address(0), "Already rented");
    require(_isBorrowabe(lend), "Not borrowable");
    lend.payment.transferFrom(_msgSender(), lend.lender, lend.totalPrice);

    _rent(lendId, lend);

    emit RentStarted(lendId, _msgSender(), address(0), 0, 0);
  }

  function rentWithGuarantor(
    uint96 lendId,
    address guarantor,
    uint120 guarantBalance,
    uint16 guarantFee,
    bytes calldata signature
  ) external {
    Lend memory lend = lends[lendId];
    require(lend.lender != address(0), "Lend not found");
    require(rentContracts[lendId].renter == address(0), "Already rented");
    require(_isBorrowabe(lend), "Not borrowable");

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

    uint120 rentPrice = lend.totalPrice - guarantBalance;
    lend.payment.transferFrom(_msgSender(), lend.lender, rentPrice);
    lend.payment.transferFrom(guarantor, lend.lender, guarantBalance);

    emit RentStarted(
      lendId,
      _msgSender(),
      guarantor,
      guarantBalance,
      guarantFee
    );

    _rent(lendId, lend);
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
  ) external {
    require(adapter.isValidData(data), "Invalid data");
    require(
      adapter.isBorrowable(address(this), _msgSender(), token, data),
      "Not borrowable"
    );
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

    AdapterCaller.logLend(_totalLend, lends[_totalLend]);

    emit LendRegistered(
      _totalLend,
      _msgSender(),
      address(adapter),
      token,
      payment,
      pricePerSec,
      totalPrice,
      autoReRegister,
      data
    );

    _totalLend++;
  }

  function renewalLend(
    uint96 lendId,
    address payment,
    uint120 pricePerSec,
    uint120 totalPrice,
    bool autoReRegister,
    bytes calldata data
  ) external {
    Lend memory lend = lends[lendId];
    require(lend.lender == _msgSender(), "Not lender");
    require(rentContracts[lendId].renter == address(0), "Already rented");
    require(lend.adapter.isValidData(data), "Invalid data");
    require(
      lend.adapter.isBorrowable(address(this), _msgSender(), lend.token, data),
      "Not borrowable"
    );
    lends[lendId] = Lend({
      lender: _msgSender(),
      adapter: lend.adapter,
      token: lend.token,
      payment: IERC20(payment),
      pricePerSec: pricePerSec,
      totalPrice: totalPrice,
      autoReRegister: autoReRegister,
      data: data
    });

    AdapterCaller.logLend(_totalLend, lends[_totalLend]);

    emit LendRegistered(
      lendId,
      _msgSender(),
      address(lend.adapter),
      lend.token,
      payment,
      pricePerSec,
      totalPrice,
      autoReRegister,
      data
    );
  }

  function cancelLend(uint96 lendId) external {
    Lend memory lend = lends[lendId];
    require(lend.lender == _msgSender(), "Not lender");
    require(rentContracts[lendId].renter == address(0), "Already rented");

    AdapterCaller.cancelLendTransfer(
      lend.adapter,
      address(this),
      _msgSender(),
      lend.token,
      lend.data
    );

    delete lends[lendId];
  }

  function isBorrowable(uint96 lendId) external view returns (bool) {
    Lend memory lend = lends[lendId];
    return _isBorrowabe(lend);
  }

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
    )
  {
    Lend memory lend = lends[lendId];
    return (
      lend.lender,
      address(lend.adapter),
      lend.token,
      address(lend.payment),
      lend.pricePerSec,
      lend.totalPrice,
      lend.autoReRegister,
      lend.data
    );
  }

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
    )
  {
    Lend memory lend = lends[lendId];
    return (
      address(lend.payment),
      lend.pricePerSec,
      lend.totalPrice,
      lend.autoReRegister,
      lend.data
    );
  }

  function updateMinimalRentTime(
    uint96 minimalRentTime_
  ) external onlyRole(PROTOCOL_OWNER_ROLE) {
    emit MinimumRentTimeUpdated(minimalRentTime, minimalRentTime_);
    minimalRentTime = minimalRentTime_;
  }

  function updateRentFee(
    uint16 rentFee_
  ) external onlyRole(PROTOCOL_OWNER_ROLE) {
    _updateProtocolFee(rentFee_);
  }
}
