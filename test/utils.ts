import { ethers } from "hardhat";

export const missingRole = () => {
  return /AccessControl: account 0x(.*) is missing role 0x(.*)/;
};

export const to1155Data = (id: number, amount: number) => {
  return ethers.utils.solidityPack(["uint256", "uint256"], [id, amount]);
};
