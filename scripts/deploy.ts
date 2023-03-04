import { ethers } from "hardhat";

async function main() {
  const Receiver = await ethers.getContractFactory("Only1155Receiver");
  const receiver = await Receiver.deploy();
  await receiver.deployed();

  const ERC721Adapter = await ethers.getContractFactory("ERC721Adapter");
  const erc721Adapter = await ERC721Adapter.deploy();
  await erc721Adapter.deployed();

  const ERC1155Adapter = await ethers.getContractFactory("ERC1155Adapter");
  const erc1155Adapter = await ERC1155Adapter.deploy();
  await erc1155Adapter.deployed();

  const Market = await ethers.getContractFactory("Market");
  const market = await Market.deploy(receiver.address, erc721Adapter.address, erc1155Adapter.address);
  await market.deployed();

  await market.setSupportedReceiveSelector(receiver.interface.getSighash("onERC1155Received"), true);
  await market.setSupportedReceiveSelector(receiver.interface.getSighash("onERC1155BatchReceived"), true);

  console.log("Market deployed to:", market.address);
  console.log("ERC721Adapter deployed to:", erc721Adapter.address);
  console.log("ERC1155Adapter deployed to:", erc1155Adapter.address);
  console.log("Receiver deployed to:", receiver.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
