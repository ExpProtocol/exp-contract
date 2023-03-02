// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../interfaces/IAdapter.sol";
import "../interfaces/IIMarket.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library AdapterCaller {
  function logLend(uint96 lendId, IMarket.Lend memory lend) internal {
    (bool succsess, ) = address(lend.adapter).delegatecall(
      abi.encodeWithSignature(
        "logLend(uint96,address,address,address,address,uint120,uint120,bool,bytes)",
        lendId,
        address(this),
        lend.lender,
        lend.token,
        lend.payment,
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
    bytes memory data
  ) internal {
    (bool succsess, ) = address(adapter).delegatecall(
      abi.encodeWithSignature(
        "lendTransfer(address,address,address,address,bytes)",
        market,
        lender,
        token,
        renter,
        data
      )
    );
    require(succsess, "AdapterCaller: lendTransfer failed");
  }

  function cancelLendTransfer(
    IAdapter adapter,
    address market,
    address lender,
    address token,
    bytes memory data
  ) internal {
    (bool succsess, ) = address(adapter).delegatecall(
      abi.encodeWithSignature(
        "cancelLendTransfer(address,address,address,bytes)",
        market,
        lender,
        token,
        data
      )
    );

    require(succsess, "AdapterCaller: cancelLendTransfer failed");
  }

  function returnTransfer(
    IAdapter adapter,
    address market,
    address lender,
    address token,
    address renter,
    bool autoReRegister,
    bytes memory data
  ) internal {
    (bool succsess, ) = address(adapter).delegatecall(
      abi.encodeWithSignature(
        "returnTransfer(address,address,address,address,bool,bytes)",
        market,
        lender,
        token,
        renter,
        autoReRegister,
        data
      )
    );

    require(succsess, "AdapterCaller: returnTransfer failed");
  }
}
