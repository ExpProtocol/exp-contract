// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FeeManager is AccessControlEnumerable {
  event ProtocolFeeUpdated(uint16 oldrotocolFee, uint16 newProtocolFee);

  mapping(IERC20 => uint256) public collectedFees;

  uint16 private _protocolFee = 20; // (1/x)% 5% = 20
  bytes32 constant TREASURY_ROLE = keccak256("PROTOCOL_OWNER_ROLE");

  function claimFee(address payment_) public {
    IERC20 payment = IERC20(payment_);
    uint256 targets = getRoleMemberCount(TREASURY_ROLE);
    uint256 valuePerTarget = collectedFees[payment] / targets;
    for (uint256 i = 0; i < targets; i++) {
      address target = getRoleMember(TREASURY_ROLE, i);
      payment.transfer(target, valuePerTarget);
    }
  }

  function protocolFee() external view returns (uint256) {
    return _protocolFee;
  }

  function _collectFee(IERC20 payment, uint256 amount) internal returns (uint256 fee) {
    fee = amount / _protocolFee;
    collectedFees[payment] += fee;
  }

  function _updateProtocolFee(uint16 newProtocolFee) internal {
    uint16 oldProtocolFee = _protocolFee;
    _protocolFee = newProtocolFee;
    emit ProtocolFeeUpdated(oldProtocolFee, newProtocolFee);
  }
}
