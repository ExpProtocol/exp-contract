import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";

describe("Market", function () {
  async function deployOneYearLockFixture() {
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

    const Erc721 = await ethers.getContractFactory("TestERC721Token");
    const erc721 = await Erc721.deploy();
    await erc721.deployed();

    const Erc1155 = await ethers.getContractFactory("Test1155Token");
    const erc1155 = await Erc1155.deploy();
    await erc1155.deployed();

    return {
      market,
      periphery,
      erc721,
      erc1155,
    };
  }
});
