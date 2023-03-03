import { ethers } from "hardhat";

async function main() {
  const Market = await ethers.getContractFactory("Market");
  const market = await Market.deploy();
  await market.deployed();

  const ERC721Adapter = await ethers.getContractFactory("ERC721Adapter");
  const erc721Adapter = await ERC721Adapter.deploy();
  await erc721Adapter.deployed();

  const ERC1155Adapter = await ethers.getContractFactory("ERC1155Adapter");
  const erc1155Adapter = await ERC1155Adapter.deploy();
  await erc1155Adapter.deployed();

  const Periphery = await ethers.getContractFactory("Periphery");
  const periphery = await Periphery.deploy(
    market.address,
    erc721Adapter.address,
    erc1155Adapter.address
  );
  await periphery.deployed();

  console.log("Market deployed to:", market.address);
  console.log("ERC721Adapter deployed to:", erc721Adapter.address);
  console.log("ERC1155Adapter deployed to:", erc1155Adapter.address);
  console.log("Periphery deployed to:", periphery.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
