// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IAdapter.sol";
import "../interfaces/IMarket.sol";
import "hardhat/console.sol";

library AdapterCaller {
  function logLend(uint96 lendId, IMarket.Lend memory lend) internal {
    (bool succsess, ) = address(lend.adapter).delegatecall(
      abi.encodeWithSelector(
        IAdapter.logLend.selector,
        lendId,
        lend.lender,
        lend.token,
        address(lend.payment),
        lend.pricePerSec,
        lend.totalPrice,
        lend.autoReRegister,
        lend.data
      )
    );

    require(succsess, "AdapterCaller: logLend failed");
  }

  function lendTransfer(
    IAdapter adapter,
    address market,
    address lender,
    address token,
    address renter,
    bool isLocked,
    bytes memory data
  ) internal {
    (bool succsess, ) = address(adapter).delegatecall(
      abi.encodeWithSelector(IAdapter.lendTransfer.selector, market, lender, token, renter, isLocked, data)
    );
    require(succsess, "AdapterCaller: lendTransfer failed");
  }

  function cancelLendTransfer(
    IAdapter adapter,
    address market,
    address lender,
    address token,
    bool isLocked,
    bytes memory data
  ) internal {
    (bool succsess, ) = address(adapter).delegatecall(
      abi.encodeWithSelector(IAdapter.cancelLendTransfer.selector, market, lender, token, isLocked, data)
    );

    require(succsess, "AdapterCaller: cancelLendTransfer failed");
  }

  function returnTransfer(
    IAdapter adapter,
    address market,
    address lender,
    address token,
    address renter,
    bool isLocked,
    bool autoReRegister,
    bytes memory data
  ) internal {
    (bool succsess, ) = address(adapter).delegatecall(
      abi.encodeWithSelector(
        IAdapter.returnTransfer.selector,
        market,
        lender,
        token,
        renter,
        isLocked,
        autoReRegister,
        data
      )
    );

    require(succsess, "AdapterCaller: returnTransfer failed");
  }
}
