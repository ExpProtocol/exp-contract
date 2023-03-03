import { anyUint } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Market", function () {
  async function deployFull() {
    const [owner, otherAccount, guarantor] = await ethers.getSigners();

    const ERC721Adapter = await ethers.getContractFactory("ERC721Adapter");
    const erc721Adapter = await ERC721Adapter.deploy();
    await erc721Adapter.deployed();

    const ERC1155Adapter = await ethers.getContractFactory("ERC1155Adapter");
    const erc1155Adapter = await ERC1155Adapter.deploy();
    await erc1155Adapter.deployed();

    const Market = await ethers.getContractFactory("Market");
    const market = await Market.deploy(erc721Adapter.address, erc1155Adapter.address);
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

    return {
      owner,
      otherAccount,
      guarantor,
      market,
      erc721Adapter,
      erc1155Adapter,
      erc20,
      erc721,
      erc1155,
    };
  }

  describe("Deployment", () => {
    it("Should set parameters correctly", async () => {
      const { market, erc721Adapter, erc1155Adapter } = await loadFixture(deployFull);
      expect(await market.erc721Adapter()).to.equal(erc721Adapter.address);
      expect(await market.erc1155Adapter()).to.equal(erc1155Adapter.address);

      expect(await market.lendCount()).to.equal(0);
      expect(await market.minimalRentTime()).to.equal(86400);
      expect(await market.protocolFee()).to.equal(20);
    });
  });
  describe("Lending", () => {
    it("should be able to register a 1155 token", async () => {
      const { owner, market, erc1155Adapter, erc20, erc1155 } = await loadFixture(deployFull);
      await erc1155.mint(owner.address, 1, 100);
      await erc1155.setApprovalForAll(market.address, true);
      await expect(market.connect(owner).lend1155(erc1155.address, 1, 1, erc20.address, 1, 100000, false))
        .to.emit(market, "LendRegistered")
        .to.emit(erc1155Adapter, "ERC1155LendRegistered")
        .withArgs(0, owner.address, erc1155.address, erc20.address, 1, 1, 1, 100000, false);
    });

    it("should be able to register a 721 token", async () => {
      const { owner, market, erc721Adapter, erc20, erc721 } = await loadFixture(deployFull);
      await erc721.mint(owner.address, 1);
      await erc721.approve(market.address, 1);
      await expect(market.connect(owner).lend721(erc721.address, 1, erc20.address, 1, 100000, false))
        .to.emit(market, "LendRegistered")
        .to.emit(erc721Adapter, "ERC721LendRegistered")
        .withArgs(0, owner.address, erc721.address, erc20.address, 1, 1, 100000, false);
    });
  });

  describe("Renting", () => {
    it("should be able to rent a 1155 token", async () => {
      const { owner, otherAccount, market, erc20, erc1155 } = await loadFixture(deployFull);
      await erc1155.mint(owner.address, 1, 100);
      await erc1155.setApprovalForAll(market.address, true);
      await market.connect(owner).lend1155(erc1155.address, 1, 1, erc20.address, 1, 100000, false);

      await erc20.mint(otherAccount.address, 100000);
      await erc20.connect(otherAccount).approve(market.address, 100000);
      await expect(market.connect(otherAccount).rent(0))
        .to.emit(market, "RentStarted")
        .withArgs(0, otherAccount.address, ethers.constants.AddressZero, 0, 0)
        .to.emit(erc1155, "TransferSingle")
        .withArgs(market.address, owner.address, otherAccount.address, 1, 1)
        .to.emit(erc20, "Transfer")
        .withArgs(otherAccount.address, market.address, 100000);

      expect(await erc1155.balanceOf(otherAccount.address, 1)).to.equal(1);
      expect(await erc1155.balanceOf(owner.address, 1)).to.equal(99);
      expect(await erc20.balanceOf(otherAccount.address)).to.equal(0);
      expect(await erc20.balanceOf(market.address)).to.equal(100000);
    });

    it("should be able to rent a 721 token", async () => {
      const { owner, otherAccount, market, erc20, erc721 } = await loadFixture(deployFull);
      await erc721.mint(owner.address, 1);
      await erc721.approve(market.address, 1);
      await market.connect(owner).lend721(erc721.address, 1, erc20.address, 1, 100000, false);

      await erc20.mint(otherAccount.address, 100000);
      await erc20.connect(otherAccount).approve(market.address, 100000);
      await expect(market.connect(otherAccount).rent(0))
        .to.emit(market, "RentStarted")
        .withArgs(0, otherAccount.address, ethers.constants.AddressZero, 0, 0)
        .to.emit(erc721, "Transfer")
        .withArgs(owner.address, otherAccount.address, 1)
        .to.emit(erc20, "Transfer")
        .withArgs(otherAccount.address, market.address, 100000);

      expect(await erc721.ownerOf(1)).to.equal(otherAccount.address);
      expect(await erc20.balanceOf(otherAccount.address)).to.equal(0);
      expect(await erc20.balanceOf(market.address)).to.equal(100000);
    });

    it("should be able to rent a 1155 token with a guarantor", async () => {
      const { owner, otherAccount, guarantor, market, erc20, erc721 } = await loadFixture(deployFull);
      await erc721.mint(owner.address, 1);
      await erc721.approve(market.address, 1);
      await market.connect(owner).lend721(erc721.address, 1, erc20.address, 1, 100000, false);

      await erc20.mint(otherAccount.address, 50000);
      await erc20.connect(otherAccount).approve(market.address, 50000);
      await erc20.mint(guarantor.address, 50000);
      await erc20.connect(guarantor).approve(market.address, 50000);

      const signature = guarantor._signTypedData(
        {
          chainId: await ethers.provider.getNetwork().then((n) => n.chainId),
          verifyingContract: market.address,
          name: "EXP-Market",
          version: "1",
        },
        {
          GuarantorRequest: [
            { type: "uint96", name: "lendId" },
            { type: "uint120", name: "guarantorBalance" },
            { type: "uint16", name: "guarantorFee" },
            { type: "uint24", name: "nonce" },
          ],
        },
        {
          lendId: 0,
          guarantorBalance: 50000,
          guarantorFee: 20, //5%
          nonce: 1,
        }
      );

      await erc20.connect(otherAccount).approve(market.address, 50000);
      await erc20.connect(guarantor).approve(market.address, 50000);
      await expect(await market.connect(otherAccount).rentWithGuarantor(0, guarantor.address, 50000, 20, signature));
    });

    it("should be able to return a 1155 token", async () => {
      const { owner, otherAccount, market, erc20, erc1155 } = await loadFixture(deployFull);
      await erc1155.mint(owner.address, 1, 100);
      await erc1155.setApprovalForAll(market.address, true);
      await market.connect(owner).lend1155(erc1155.address, 1, 1, erc20.address, 1, 100000, false);

      await erc20.mint(otherAccount.address, 100000);
      await erc20.connect(otherAccount).approve(market.address, 100000);
      await market.connect(otherAccount).rent(0);

      await time.increase(86400);

      await erc1155.connect(otherAccount).setApprovalForAll(market.address, true);
      await expect(market.connect(otherAccount).returnToken(0))
        .to.emit(market, "RentReturned")
        .withArgs(0, otherAccount.address)
        .to.emit(erc1155, "TransferSingle")
        .withArgs(market.address, otherAccount.address, owner.address, 1, 1)
        .to.emit(erc20, "Transfer")
        .withArgs(market.address, owner.address, anyUint)
        .to.emit(erc20, "Transfer")
        .withArgs(market.address, otherAccount.address, anyUint);

      expect(await erc20.balanceOf(otherAccount.address)).to.within(0, 13600);
      expect(await erc20.balanceOf(owner.address)).to.within(82080, 100000);
      expect(await erc20.balanceOf(market.address)).to.within(4320, 13600);
    });

    it("should be able to return a 721 token", async () => {
      const { owner, otherAccount, market, erc20, erc721 } = await loadFixture(deployFull);
      await erc721.mint(owner.address, 1);
      await erc721.approve(market.address, 1);
      await market.connect(owner).lend721(erc721.address, 1, erc20.address, 1, 100000, false);

      await erc20.mint(otherAccount.address, 100000);
      await erc20.connect(otherAccount).approve(market.address, 100000);
      await market.connect(otherAccount).rent(0);

      await time.increase(86400);

      await erc721.connect(otherAccount).approve(market.address, 1);
      await expect(market.connect(otherAccount).returnToken(0))
        .to.emit(market, "RentReturned")
        .withArgs(0, otherAccount.address)
        .to.emit(erc721, "Transfer")
        .withArgs(otherAccount.address, owner.address, 1)
        .to.emit(erc20, "Transfer")
        .withArgs(market.address, owner.address, anyUint)
        .to.emit(erc20, "Transfer")
        .withArgs(market.address, otherAccount.address, anyUint);

      expect(await erc20.balanceOf(otherAccount.address)).to.within(0, 13600);
      expect(await erc20.balanceOf(owner.address)).to.within(82080, 100000);
      expect(await erc20.balanceOf(market.address)).to.within(4320, 13600);
    });
  });
});
