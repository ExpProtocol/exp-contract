import { ethers } from "hardhat";

async function main() {
  const ERC20 = await ethers.getContractFactory("Test20Token");
  const erc20 = await ERC20.deploy();
  await erc20.deployed();

  const ERC721 = await ethers.getContractFactory("Test721Token");
  const erc721 = await ERC721.deploy();
  await erc721.deployed();

  const ERC1155 = await ethers.getContractFactory("Test1155Token");
  const erc1155 = await ERC1155.deploy();
  await erc1155.deployed();

  console.log("ERC20 deployed to:", erc20.address);
  console.log("ERC721 deployed to:", erc721.address);
  console.log("ERC1155 deployed to:", erc1155.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
