import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";

describe("Market", function () {
  async function deployFull() {
    const [owner, otherAccount] = await ethers.getSigners();

    const ERC721Adapter = await ethers.getContractFactory("ERC721Adapter");
    const erc721Adapter = await ERC721Adapter.deploy();
    await erc721Adapter.deployed();

    const ERC1155Adapter = await ethers.getContractFactory("ERC1155Adapter");
    const erc1155Adapter = await ERC1155Adapter.deploy();
    await erc1155Adapter.deployed();

    const Market = await ethers.getContractFactory("Market");
    const market = await Market.deploy(
      erc721Adapter.address,
      erc1155Adapter.address
    );
    await market.deployed();

    const Erc20 = await ethers.getContractFactory("Test20Token");
    const erc20 = await Erc20.deploy();
    await erc20.deployed();

    const Erc721 = await ethers.getContractFactory("Test721Token");
    const erc721 = await Erc721.deploy();
    await erc721.deployed();

    const Erc1155 = await ethers.getContractFactory("Test1155Token");
    const erc1155 = await Erc1155.deploy();
    await erc1155.deployed();

    return { owner, otherAccount, market, erc20, erc721, erc1155 };
  }

  it("should be able to register a 1155 token", async () => {
    const { owner, market, erc20, erc1155 } = await loadFixture(deployFull);
    await erc1155.mint(owner.address, 1, 100);
    await erc1155.setApprovalForAll(market.address, true);
    await market
      .connect(owner)
      .lend1155(erc1155.address, 1, 1, erc20.address, 100000, 1, false);
  });

  it("should be able to register a 721 token", async () => {
    const { owner, market, erc20, erc721 } = await loadFixture(deployFull);
    await erc721.mint(owner.address, 1);
    await erc721.approve(market.address, 1);
    await market
      .connect(owner)
      .lend721(erc721.address, 1, erc20.address, 100000, 1, false);
  });

  it("should be able to rent a 1155 token", async () => {
    const { owner, otherAccount, market, erc20, erc1155 } = await loadFixture(
      deployFull
    );
    await erc1155.mint(owner.address, 1, 100);
    await erc1155.setApprovalForAll(market.address, true);
    await market
      .connect(owner)
      .lend1155(erc1155.address, 1, 1, erc20.address, 100000, 1, false);

    await erc20.mint(otherAccount.address, 100000);
    await erc20.connect(otherAccount).approve(market.address, 100000);
    await market.connect(otherAccount).rent(0);
  });
});
