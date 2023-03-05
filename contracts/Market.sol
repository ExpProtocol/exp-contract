// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "./interfaces/IMarket.sol";
import "./interfaces/IAdapter.sol";
import "./libraries/AdapterCaller.sol";
import "./libraries/FeeManager.sol";
import "./adapters/ERC721Adapter.sol";
import "./adapters/ERC1155Adapter.sol";
import "hardhat/console.sol";

contract Market is IMarket, AccessControlEnumerable, EIP712, FeeManager {
  address public receiver;
  ERC721Adapter public erc721Adapter;
  ERC1155Adapter public erc1155Adapter;

  uint96 private _totalLend;
  uint96 public minimalRentTime = 1 days; // 1 day

  mapping(uint96 => Lend) private lends;
  mapping(uint96 => RentContract) private rentContracts;
  mapping(address => uint24) public usedNonces;
  mapping(bytes4 => bool) private supportedInterfaces;
  mapping(bytes4 => bool) private supportedReceiveSelectors;

  bytes32 public constant PROTOCOL_OWNER_ROLE = keccak256("PROTOCOL_OWNER_ROLE");

  bytes32 public constant GUARANTOR_REQUEST_TYPE_HASH =
    keccak256(
      abi.encodePacked(
        "GuarantorRequest(",
        "uint96 lendId,",
        "address renter,",
        "uint120 guarantorBalance,",
        "uint16 guarantorFee,",
        "uint24 nonce"
        ")"
      )
    );

  constructor(address receiver_, address erc721Adapter_, address erc1155Adapter_) EIP712("EXP-Market", "1") {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(PROTOCOL_OWNER_ROLE, _msgSender());
    _setupRole(TREASURY_ROLE, _msgSender());

    receiver = receiver_;
    erc721Adapter = ERC721Adapter(erc721Adapter_);
    erc1155Adapter = ERC1155Adapter(erc1155Adapter_);

    supportedInterfaces[type(IERC165).interfaceId] = true;
    supportedInterfaces[type(IAccessControl).interfaceId] = true;
    supportedInterfaces[type(IAccessControlEnumerable).interfaceId] = true;
  }

  function _blockTimeStamp() private view returns (uint96) {
    return uint96(block.timestamp);
  }

  function _isBorrowabel(Lend memory lend) private view returns (bool) {
    return lend.adapter.isBorrowable(address(this), lend.lender, lend.token, lend.isLocked, lend.data);
  }

  function _isReturnable(uint96 lendId) private view returns (bool) {
    Lend memory lend = lends[lendId];
    RentContract memory rentContract = rentContracts[lendId];
    return
      lend.adapter.isReturnable(address(this), _msgSender(), lend.token, lend.data) &&
      rentContract.renter == _msgSender();
  }

  function returnToken(uint96 lendId) public {
    Lend storage lend = lends[lendId];
    RentContract memory rentContract = rentContracts[lendId];
    uint120 rentSec = _blockTimeStamp() - rentContract.startTime;
    uint120 rentTime = ((rentSec / minimalRentTime) + 1) * minimalRentTime;
    uint120 rentFee = rentTime * lend.pricePerSec;
    require(lend.totalPrice > rentFee, "Already overtime");
    require(_isReturnable(lendId), "Not returnable");

    lend.isLocked = AdapterCaller.returnTransfer(
      lend.adapter,
      address(this),
      lend.lender,
      lend.token,
      _msgSender(),
      lend.isLocked,
      lend.autoReRegister,
      lend.data
    );

    uint120 totalReturn = lend.totalPrice - rentFee;
    if (rentContract.guarantor == address(0)) {
      IERC20(lend.payment).transfer(rentContract.renter, totalReturn);
    } else {
      uint120 shoudReturnForGuarant = rentContract.guarantorBalance +
        rentContract.guarantorBalance /
        rentContract.guarantorFee;
      if (shoudReturnForGuarant > totalReturn) {
        IERC20(lend.payment).transfer(rentContract.guarantor, totalReturn);
      } else {
        IERC20(lend.payment).transfer(rentContract.guarantor, shoudReturnForGuarant);
        IERC20(lend.payment).transfer(rentContract.renter, totalReturn - shoudReturnForGuarant);
      }
    }

    uint256 fee = _collectFee(lend.payment, rentFee);
    IERC20(lend.payment).transfer(lend.lender, rentFee - fee);

    emit RentReturned(lendId, _msgSender(), lend.autoReRegister);

    if (lend.isLocked == false) delete lends[lendId];
    delete rentContracts[lendId];
  }

  function claim(uint96 lendId) public {
    Lend memory lend = lends[lendId];
    RentContract memory rentContract = rentContracts[lendId];
    uint96 rentTime = _blockTimeStamp() - rentContract.startTime;
    uint120 rentFee = rentTime * lend.pricePerSec;
    require(rentContract.renter == address(0), "Already rentured");
    require(lend.lender == _msgSender(), "Not lender");
    require(rentFee > lend.totalPrice, "Not overtime");

    uint256 totalPrice = lend.totalPrice;
    uint256 fee = _collectFee(lend.payment, totalPrice);
    IERC20(lend.payment).transfer(lend.lender, totalPrice - fee);

    emit RentClaimed(0, _msgSender());

    delete rentContracts[lendId];
    delete lends[lendId];
  }

  function _rent(
    uint96 lendId,
    Lend memory lend,
    address guarantor,
    uint120 guarantorBalance,
    uint16 guarantorFee
  ) private {
    AdapterCaller.lendTransfer(
      lend.adapter,
      address(this),
      lend.lender,
      lend.token,
      _msgSender(),
      lend.isLocked,
      lend.data
    );

    rentContracts[lendId] = RentContract({
      renter: _msgSender(),
      startTime: _blockTimeStamp(),
      guarantor: guarantor,
      guarantorBalance: guarantorBalance,
      guarantorFee: guarantorFee
    });
  }

  function rent(uint96 lendId) external {
    Lend memory lend = lends[lendId];
    require(lend.lender != address(0), "Lend not found");
    require(rentContracts[lendId].renter == address(0), "Already rented");
    require(_isBorrowabel(lend), "Not borrowable");
    lend.payment.transferFrom(_msgSender(), address(this), lend.totalPrice);

    _rent(lendId, lend, address(0), 0, 0);

    emit RentStarted(lendId, _msgSender(), _blockTimeStamp(), address(0), 0, 0);
  }

  function rentWithGuarantor(
    uint96 lendId,
    address guarantor,
    uint120 guarantorBalance,
    uint16 guarantorFee,
    bytes calldata signature
  ) external {
    Lend memory lend = lends[lendId];
    require(lend.lender != address(0), "Lend not found");
    require(rentContracts[lendId].renter == address(0), "Already rented");
    require(_isBorrowabel(lend), "Not borrowable");

    bytes32 guarantorDigest = _hashTypedDataV4(
      keccak256(
        abi.encode(
          GUARANTOR_REQUEST_TYPE_HASH,
          lendId,
          _msgSender(),
          guarantorBalance,
          guarantorFee,
          usedNonces[guarantor] + 1
        )
      )
    );

    require(ECDSA.recover(guarantorDigest, signature) == guarantor, "Invalid signature");

    uint120 rentPrice = lend.totalPrice - guarantorBalance;
    lend.payment.transferFrom(_msgSender(), address(this), rentPrice);
    lend.payment.transferFrom(guarantor, address(this), guarantorBalance);

    emit RentStarted(lendId, _msgSender(), _blockTimeStamp(), guarantor, guarantorBalance, guarantorFee);

    _rent(lendId, lend, guarantor, guarantorBalance, guarantorFee);
    usedNonces[guarantor]++;
  }

  function registerToLend(
    IAdapter adapter,
    address token,
    address payment,
    uint120 pricePerSec,
    uint120 totalPrice,
    bool autoReRegister,
    bytes memory data
  ) public {
    require(adapter.isValidData(data), "Invalid data");
    require(adapter.isBorrowable(address(this), _msgSender(), token, false, data), "Not borrowable");
    lends[_totalLend] = Lend({
      lender: _msgSender(),
      adapter: IAdapter(adapter),
      token: token,
      payment: IERC20(payment),
      pricePerSec: pricePerSec,
      totalPrice: totalPrice,
      isLocked: false,
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

  function lend721(
    address token,
    uint256 tokenId,
    address payment,
    uint120 pricePerSec,
    uint120 totalPrice,
    bool autoReRegister
  ) external {
    registerToLend(
      erc721Adapter,
      token,
      payment,
      pricePerSec,
      totalPrice,
      autoReRegister,
      abi.encode(ERC721Adapter.DataFormat(tokenId))
    );
  }

  function lend1155(
    address token,
    uint256 tokenId,
    uint256 amount,
    address payment,
    uint120 pricePerSec,
    uint120 totalPrice,
    bool autoReRegister
  ) external {
    registerToLend(
      erc1155Adapter,
      token,
      payment,
      pricePerSec,
      totalPrice,
      autoReRegister,
      abi.encode(ERC1155Adapter.DataFormat(tokenId, amount))
    );
  }

  function cancelLend(uint96 lendId) external {
    Lend memory lend = lends[lendId];
    require(lend.lender == _msgSender(), "Not lender");
    require(rentContracts[lendId].renter == address(0), "Already rented");

    AdapterCaller.cancelLendTransfer(lend.adapter, address(this), _msgSender(), lend.token, lend.isLocked, lend.data);

    emit LendCanceled(lendId, _msgSender());

    delete lends[lendId];
  }

  function isBorrowable(uint96 lendId) external view returns (bool) {
    Lend memory lend = lends[lendId];
    return _isBorrowabel(lend);
  }

  function lendCount() external view returns (uint256) {
    return _totalLend;
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
    returns (address renter, uint96 startTime, address guarantor, uint120 guarantorBalance, uint16 guarantorFee)
  {
    RentContract memory rentContract = rentContracts[lendId];
    return (
      rentContract.renter,
      rentContract.startTime,
      rentContract.guarantor,
      rentContract.guarantorBalance,
      rentContract.guarantorFee
    );
  }

  function updateMinimalRentTime(uint96 minimalRentTime_) external onlyRole(PROTOCOL_OWNER_ROLE) {
    emit MinimumRentTimeUpdated(minimalRentTime, minimalRentTime_);
    minimalRentTime = minimalRentTime_;
  }

  function updateRentFee(uint16 rentFee_) external onlyRole(PROTOCOL_OWNER_ROLE) {
    _updateProtocolFee(rentFee_);
  }

  function updateAdapters(address erc721Adapter_, address erc1155Adapter_) external onlyRole(PROTOCOL_OWNER_ROLE) {
    emit AdaptersUpdated(address(erc721Adapter), address(erc1155Adapter), erc721Adapter_, erc1155Adapter_);
    erc721Adapter = ERC721Adapter(erc721Adapter_);
    erc1155Adapter = ERC1155Adapter(erc1155Adapter_);
  }

  function updateReceiver(address receiver_) external onlyRole(PROTOCOL_OWNER_ROLE) {
    emit ReceiverUpdated(receiver, receiver_);
    receiver = receiver_;
  }

  function setSupportedReceiveSelector(bytes4 selector, bool supported) external onlyRole(PROTOCOL_OWNER_ROLE) {
    emit SupportedReceiveSelectorUpdated(selector, supported);
    supportedReceiveSelectors[selector] = supported;
  }

  function supportsReceiveSelector(bytes4 selector) external view returns (bool) {
    return supportedReceiveSelectors[selector];
  }

  function setSupportedInterface(bytes4 interfaceId, bool supported) external onlyRole(PROTOCOL_OWNER_ROLE) {
    emit SupportedInterfaceIdUpdated(interfaceId, supported);
    supportedInterfaces[interfaceId] = supported;
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControlEnumerable) returns (bool) {
    return supportedInterfaces[interfaceId];
  }

  receive() external payable {
    revert("Not supported");
  }

  fallback(bytes calldata call) external payable returns (bytes memory) {
    require(supportedReceiveSelectors[msg.sig], "Not supported receiver selector");
    (bool success, bytes memory data) = address(receiver).delegatecall(call);
    require(success, "Receiver call failed");
    return data;
  }
}
