import { anyUint } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { missingRole, to1155Data } from "./utils";

describe("Market", function () {
  async function deployFull() {
    const [owner, otherAccount, guarantor] = await ethers.getSigners();

    const Receiver = await ethers.getContractFactory("Only1155Receiver");
    const receiver = await Receiver.deploy();
    await receiver.deployed();

    const ERC721Adapter = await ethers.getContractFactory("ERC721Adapter");
    const erc721Adapter = await ERC721Adapter.deploy();
    await erc721Adapter.deployed();

    const ERC1155Adapter = await ethers.getContractFactory("ERC1155Adapter");
    const erc1155Adapter = await ERC1155Adapter.deploy();
    await erc1155Adapter.deployed();

    const Market = await ethers.getContractFactory("TestMarket");
    const market = await Market.deploy(receiver.address, erc721Adapter.address, erc1155Adapter.address);
    await market.deployed();

    await market.setReceiverSelector(receiver.interface.getSighash("onERC1155Received"), true);
    await market.setReceiverSelector(receiver.interface.getSighash("onERC1155BatchReceived"), true);

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

  describe("Misc", () => {
    describe("Update params", () => {
      it("Should be able to update minimal rent time", async () => {
        const { market } = await loadFixture(deployFull);
        await expect(market.updateMinimalRentTime(1)).to.emit(market, "MinimumRentTimeUpdated").withArgs(86400, 1);
        expect(await market.minimalRentTime()).to.equal(1);
      });
      it("Should be able to update protocol fee", async () => {
        const { market } = await loadFixture(deployFull);
        await expect(market.updateRentFee(1)).to.emit(market, "ProtocolFeeUpdated").withArgs(20, 1);
        expect(await market.protocolFee()).to.equal(1);
      });
    });
    describe("Role", () => {
      it("Should be able to update after grant Role", async () => {
        const { market, otherAccount } = await loadFixture(deployFull);
        await market.grantRole(market.PROTOCOL_OWNER_ROLE(), otherAccount.address);
        await expect(market.connect(otherAccount).updateMinimalRentTime(1)).to.emit(market, "MinimumRentTimeUpdated");
        await expect(market.connect(otherAccount).updateRentFee(1)).to.emit(market, "ProtocolFeeUpdated");
      });
    });
    describe("Revert", () => {
      it("Should be revert to update minimal rent time", async () => {
        const { otherAccount, market } = await loadFixture(deployFull);
        await expect(market.connect(otherAccount).updateMinimalRentTime(1)).to.revertedWith(missingRole());
      });
      it("Should be revert to update protocol fee", async () => {
        const { otherAccount, market } = await loadFixture(deployFull);
        await expect(market.connect(otherAccount).updateRentFee(1)).to.revertedWith(missingRole());
      });
    });
  });

  describe("Lending", () => {
    describe("Lend", () => {
      it("should be able to register a 1155 token", async () => {
        const { owner, market, erc20, erc1155 } = await loadFixture(deployFull);
        await erc1155.mint(owner.address, 1, 100);
        await erc1155.setApprovalForAll(market.address, true);
        await expect(market.connect(owner).lend1155(erc1155.address, 1, 1, erc20.address, 1, 100000, false))
          .to.emit(market, "LendRegistered")
          .to.emit(market, "ERC1155LendRegistered")
          .withArgs(0, owner.address, erc1155.address, erc20.address, 1, 1, 1, 100000, false);
      });

      it("should be able to register a 721 token", async () => {
        const { owner, market, erc20, erc721 } = await loadFixture(deployFull);
        await erc721.mint(owner.address, 1);
        await erc721.approve(market.address, 1);
        await expect(market.connect(owner).lend721(erc721.address, 1, erc20.address, 1, 100000, false))
          .to.emit(market, "LendRegistered")
          .to.emit(market, "ERC721LendRegistered")
          .withArgs(0, owner.address, erc721.address, erc20.address, 1, 1, 100000, false);
      });

      it("Should be able to cancel lend for 1155 token", async () => {
        const { owner, market, erc20, erc1155 } = await loadFixture(deployFull);
        await erc1155.mint(owner.address, 1, 100);
        await erc1155.setApprovalForAll(market.address, true);
        await market.connect(owner).lend1155(erc1155.address, 1, 1, erc20.address, 1, 100000, false);

        await expect(market.connect(owner).cancelLend(0)).to.emit(market, "LendCanceled").withArgs(0, owner.address);
        expect((await market.lendCondition(0)).lender).to.equal(ethers.constants.AddressZero);
      });

      it("Should be able cancel lend for 721 token", async () => {
        const { owner, market, erc20, erc721 } = await loadFixture(deployFull);
        await erc721.mint(owner.address, 1);
        await erc721.approve(market.address, 1);
        await market.connect(owner).lend721(erc721.address, 1, erc20.address, 1, 100000, false);

        await expect(market.connect(owner).cancelLend(0)).to.emit(market, "LendCanceled").withArgs(0, owner.address);
        expect((await market.lendCondition(0)).lender).to.equal(ethers.constants.AddressZero);
      });

      it("Should be able to cancel lend for locked 1155 token", async () => {
        const { owner, otherAccount, market, erc20, erc1155 } = await loadFixture(deployFull);
        await erc1155.mint(owner.address, 1, 100);
        await erc1155.setApprovalForAll(market.address, true);
        await market.connect(owner).lend1155(erc1155.address, 1, 1, erc20.address, 1, 100000, true);

        await erc20.mint(otherAccount.address, 200000);
        await erc20.connect(otherAccount).approve(market.address, 100000);
        await market.connect(otherAccount).rent(0);

        await erc1155.connect(otherAccount).setApprovalForAll(market.address, true);
        await market.connect(otherAccount).returnToken(0);

        await expect(market.connect(owner).cancelLend(0))
          .to.emit(market, "LendCanceled")
          .withArgs(0, owner.address)
          .to.emit(erc1155, "TransferSingle")
          .withArgs(market.address, market.address, owner.address, 1, 1);

        expect((await market.lendCondition(0)).lender).to.equal(ethers.constants.AddressZero);
        expect(await erc1155.balanceOf(owner.address, 1)).to.equal(100);
        expect(await erc1155.balanceOf(market.address, 1)).to.equal(0);
      });

      it("Should be able to cancel lend for locked 721 token", async () => {
        const { owner, otherAccount, market, erc20, erc721 } = await loadFixture(deployFull);
        await erc721.mint(owner.address, 1);
        await erc721.approve(market.address, 1);
        await market.connect(owner).lend721(erc721.address, 1, erc20.address, 1, 100000, true);

        await erc20.mint(otherAccount.address, 200000);
        await erc20.connect(otherAccount).approve(market.address, 100000);
        await market.connect(otherAccount).rent(0);

        await erc721.connect(otherAccount).approve(market.address, 1);
        await market.connect(otherAccount).returnToken(0);

        await expect(market.connect(owner).cancelLend(0))
          .to.emit(market, "LendCanceled")
          .withArgs(0, owner.address)
          .to.emit(erc721, "Transfer")
          .withArgs(market.address, owner.address, 1);

        expect((await market.lendCondition(0)).lender).to.equal(ethers.constants.AddressZero);
        expect(await erc721.ownerOf(1)).to.equal(owner.address);
        expect(await erc721.balanceOf(market.address)).to.equal(0);
      });
    });

    describe("View", () => {
      it("Should be able to get lend data", async () => {
        const { owner, market, erc20, erc1155, erc1155Adapter } = await loadFixture(deployFull);
        await erc1155.mint(owner.address, 1, 100);
        await erc1155.setApprovalForAll(market.address, true);
        await market.connect(owner).lend1155(erc1155.address, 1, 1, erc20.address, 1, 100000, false);

        expect(await market.lendCondition(0)).to.deep.equal([
          owner.address,
          erc1155Adapter.address,
          erc1155.address,
          erc20.address,
          ...[1, 100000, false, to1155Data(1, 1)],
        ]);
      });
    });
  });

  describe("Renting", () => {
    describe("Rent", () => {
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
              { type: "address", name: "renter" },
              { type: "uint120", name: "guarantorBalance" },
              { type: "uint16", name: "guarantorFee" },
              { type: "uint24", name: "nonce" },
            ],
          },
          {
            lendId: 0,
            renter: otherAccount.address,
            guarantorBalance: 50000,
            guarantorFee: 20, //5%
            nonce: 1,
          }
        );

        await erc20.connect(otherAccount).approve(market.address, 50000);
        await erc20.connect(guarantor).approve(market.address, 50000);
        await expect(market.connect(otherAccount).rentWithGuarantor(0, guarantor.address, 50000, 20, signature))
          .to.emit(market, "RentStarted")
          .withArgs(0, otherAccount.address, guarantor.address, 50000, 20)
          .to.emit(erc721, "Transfer")
          .withArgs(owner.address, otherAccount.address, 1)
          .to.emit(erc20, "Transfer")
          .withArgs(otherAccount.address, market.address, 50000)
          .to.emit(erc20, "Transfer")
          .withArgs(guarantor.address, market.address, 50000);
      });
    });

    describe("Return", () => {
      it("should be able to return a 1155 token", async () => {
        const { owner, otherAccount, market, erc20, erc1155 } = await loadFixture(deployFull);
        await erc1155.mint(owner.address, 1, 100);
        await erc1155.setApprovalForAll(market.address, true);
        await market.connect(owner).lend1155(erc1155.address, 1, 1, erc20.address, 1, 100000, false);

        await erc20.mint(otherAccount.address, 100000);
        await erc20.connect(otherAccount).approve(market.address, 100000);
        await market.connect(otherAccount).rent(0);

        await erc1155.connect(otherAccount).setApprovalForAll(market.address, true);
        await expect(market.connect(otherAccount).returnToken(0))
          .to.emit(market, "RentReturned")
          .withArgs(0, otherAccount.address, false)
          .to.emit(erc1155, "TransferSingle")
          .withArgs(market.address, otherAccount.address, owner.address, 1, 1)
          .to.emit(erc20, "Transfer")
          .withArgs(market.address, owner.address, anyUint)
          .to.emit(erc20, "Transfer")
          .withArgs(market.address, otherAccount.address, anyUint);

        expect(await erc20.balanceOf(otherAccount.address)).to.equal(13600);
        expect(await erc20.balanceOf(owner.address)).to.equal(82080);
        expect(await erc20.balanceOf(market.address)).to.equal(4320);
      });

      it("should be able to return a 721 token", async () => {
        const { owner, otherAccount, market, erc20, erc721 } = await loadFixture(deployFull);
        await erc721.mint(owner.address, 1);
        await erc721.approve(market.address, 1);
        await market.connect(owner).lend721(erc721.address, 1, erc20.address, 1, 100000, false);

        await erc20.mint(otherAccount.address, 100000);
        await erc20.connect(otherAccount).approve(market.address, 100000);
        await market.connect(otherAccount).rent(0);

        await erc721.connect(otherAccount).approve(market.address, 1);
        await expect(market.connect(otherAccount).returnToken(0))
          .to.emit(market, "RentReturned")
          .withArgs(0, otherAccount.address, false)
          .to.emit(erc721, "Transfer")
          .withArgs(otherAccount.address, owner.address, 1)
          .to.emit(erc20, "Transfer")
          .withArgs(market.address, owner.address, anyUint)
          .to.emit(erc20, "Transfer")
          .withArgs(market.address, otherAccount.address, anyUint);

        expect(await erc20.balanceOf(otherAccount.address)).to.equal(13600);
        expect(await erc20.balanceOf(owner.address)).to.equal(82080);
        expect(await erc20.balanceOf(market.address)).to.equal(4320);
      });

      it("should be able to return a 1155 token with a guarantor", async () => {
        const { owner, otherAccount, guarantor, market, erc20, erc721 } = await loadFixture(deployFull);
        await erc721.mint(owner.address, 1);
        await erc721.approve(market.address, 1);
        await market.connect(owner).lend721(erc721.address, 1, erc20.address, 1, 200000, false);

        await erc20.mint(otherAccount.address, 150000);
        await erc20.connect(otherAccount).approve(market.address, 150000);
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
              { type: "address", name: "renter" },
              { type: "uint120", name: "guarantorBalance" },
              { type: "uint16", name: "guarantorFee" },
              { type: "uint24", name: "nonce" },
            ],
          },
          {
            lendId: 0,
            renter: otherAccount.address,
            guarantorBalance: 50000,
            guarantorFee: 20, //5%
            nonce: 1,
          }
        );

        await erc20.connect(otherAccount).approve(market.address, 150000);
        await erc20.connect(guarantor).approve(market.address, 50000);
        await market.connect(otherAccount).rentWithGuarantor(0, guarantor.address, 50000, 20, signature);

        await erc721.connect(otherAccount).approve(market.address, 1);
        await expect(market.connect(otherAccount).returnToken(0))
          .to.emit(market, "RentReturned")
          .withArgs(0, otherAccount.address, false)
          .to.emit(erc721, "Transfer")
          .withArgs(otherAccount.address, owner.address, 1)
          .to.emit(erc20, "Transfer")
          .withArgs(market.address, owner.address, anyUint)
          .to.emit(erc20, "Transfer")
          .withArgs(market.address, otherAccount.address, anyUint)
          .to.emit(erc20, "Transfer")
          .withArgs(market.address, guarantor.address, anyUint);

        expect(await erc20.balanceOf(otherAccount.address)).to.equal(61100);
        expect(await erc20.balanceOf(owner.address)).to.equal(82080);
        expect(await erc20.balanceOf(guarantor.address)).to.equal(52500);
        expect(await erc20.balanceOf(market.address)).to.equal(4320);
      });

      it("Should be only return to guarantor after semi overtime", async () => {
        const { owner, otherAccount, guarantor, market, erc20, erc721 } = await loadFixture(deployFull);
        await erc721.mint(owner.address, 1);
        await erc721.approve(market.address, 1);
        await market.connect(owner).lend721(erc721.address, 1, erc20.address, 1, 200000, false);

        await erc20.mint(otherAccount.address, 150000);
        await erc20.connect(otherAccount).approve(market.address, 150000);
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
              { type: "address", name: "renter" },
              { type: "uint120", name: "guarantorBalance" },
              { type: "uint16", name: "guarantorFee" },
              { type: "uint24", name: "nonce" },
            ],
          },
          {
            lendId: 0,
            renter: otherAccount.address,
            guarantorBalance: 50000,
            guarantorFee: 20, //5%
            nonce: 1,
          }
        );

        await erc20.connect(otherAccount).approve(market.address, 150000);
        await erc20.connect(guarantor).approve(market.address, 50000);
        await market.connect(otherAccount).rentWithGuarantor(0, guarantor.address, 50000, 20, signature);

        await time.increase(86400);

        await erc721.connect(otherAccount).approve(market.address, 1);
        await expect(market.connect(otherAccount).returnToken(0))
          .to.emit(market, "RentReturned")
          .withArgs(0, otherAccount.address, false)
          .to.emit(erc721, "Transfer")
          .withArgs(otherAccount.address, owner.address, 1)
          .to.emit(erc20, "Transfer")
          .withArgs(market.address, owner.address, anyUint)
          .to.emit(erc20, "Transfer")
          .withArgs(market.address, guarantor.address, anyUint);

        //TODO: 手動で計算して確認するべき
        expect(await erc20.balanceOf(otherAccount.address)).to.equal(0);
        expect(await erc20.balanceOf(owner.address)).to.equal(164160);
        expect(await erc20.balanceOf(guarantor.address)).to.equal(27200);
        expect(await erc20.balanceOf(market.address)).to.equal(8640);
      });

      it("Should be able to lock 1155 after return", async () => {
        const { owner, otherAccount, market, erc20, erc1155 } = await loadFixture(deployFull);
        await erc1155.mint(owner.address, 1, 100);
        await erc1155.setApprovalForAll(market.address, true);
        await market.connect(owner).lend1155(erc1155.address, 1, 1, erc20.address, 1, 100000, true);

        await erc20.mint(otherAccount.address, 100000);
        await erc20.connect(otherAccount).approve(market.address, 100000);
        await market.connect(otherAccount).rent(0);

        await erc1155.connect(otherAccount).setApprovalForAll(market.address, true);
        await market.connect(otherAccount).returnToken(0);

        expect(await erc1155.balanceOf(market.address, 1)).to.equal(1);
      });

      it("Should be able to lock 721 after return", async () => {
        const { owner, otherAccount, market, erc20, erc721 } = await loadFixture(deployFull);
        await erc721.mint(owner.address, 1);
        await erc721.approve(market.address, 1);
        await market.connect(owner).lend721(erc721.address, 1, erc20.address, 1, 100000, true);

        await erc20.mint(otherAccount.address, 100000);
        await erc20.connect(otherAccount).approve(market.address, 100000);
        await market.connect(otherAccount).rent(0);

        await erc721.connect(otherAccount).approve(market.address, 1);
        await market.connect(otherAccount).returnToken(0);

        expect(await erc721.balanceOf(market.address)).to.equal(1);
      });
    });

    describe("Rent Locked Token", () => {
      it("Should be able to rent a locked 1155 token", async () => {
        const { owner, otherAccount, market, erc20, erc1155 } = await loadFixture(deployFull);
        await erc1155.mint(owner.address, 1, 100);
        await erc1155.setApprovalForAll(market.address, true);
        await market.connect(owner).lend1155(erc1155.address, 1, 1, erc20.address, 1, 100000, true);

        await erc20.mint(otherAccount.address, 200000);
        await erc20.connect(otherAccount).approve(market.address, 100000);
        await market.connect(otherAccount).rent(0);

        await erc1155.connect(otherAccount).setApprovalForAll(market.address, true);
        await market.connect(otherAccount).returnToken(0);

        await erc20.connect(otherAccount).approve(market.address, 100000);
        await expect(market.connect(otherAccount).rent(0))
          .to.emit(market, "RentStarted")
          .withArgs(0, otherAccount.address, ethers.constants.AddressZero, 0, 0)
          .to.emit(erc1155, "TransferSingle")
          .withArgs(market.address, market.address, otherAccount.address, 1, 1)
          .to.emit(erc20, "Transfer")
          .withArgs(otherAccount.address, market.address, 100000);
      });

      it("Should able to rent a locked 721 token", async () => {
        const { owner, otherAccount, market, erc20, erc721 } = await loadFixture(deployFull);
        await erc721.mint(owner.address, 1);
        await erc721.approve(market.address, 1);
        await market.connect(owner).lend721(erc721.address, 1, erc20.address, 1, 100000, true);

        await erc20.mint(otherAccount.address, 200000);
        await erc20.connect(otherAccount).approve(market.address, 100000);
        await market.connect(otherAccount).rent(0);

        await erc721.connect(otherAccount).approve(market.address, 1);
        await market.connect(otherAccount).returnToken(0);

        await erc20.connect(otherAccount).approve(market.address, 100000);
        await expect(market.connect(otherAccount).rent(0))
          .to.emit(market, "RentStarted")
          .withArgs(0, otherAccount.address, ethers.constants.AddressZero, 0, 0)
          .to.emit(erc721, "Transfer")
          .withArgs(market.address, otherAccount.address, 1)
          .to.emit(erc20, "Transfer")
          .withArgs(otherAccount.address, market.address, 100000);
      });
    });

    describe("View", () => {
      it("Should be able to get rentCondition", async () => {
        const { owner, otherAccount, market, erc20, erc1155 } = await loadFixture(deployFull);
        await erc1155.mint(owner.address, 1, 100);
        await erc1155.setApprovalForAll(market.address, true);
        await market.connect(owner).lend1155(erc1155.address, 1, 1, erc20.address, 1, 100000, false);

        await erc20.mint(otherAccount.address, 100000);
        await erc20.connect(otherAccount).approve(market.address, 100000);
        await market.connect(otherAccount).rent(0);

        expect(await market.rentCondition(0)).to.deep.equal([erc20.address, 1, 100000, false, to1155Data(1, 1)]);
      });
    });

    describe("Revert", () => {
      it("Should be revert with overtime", async () => {
        const { owner, otherAccount, market, erc20, erc721 } = await loadFixture(deployFull);
        await erc721.mint(owner.address, 1);
        await erc721.approve(market.address, 1);
        await market.connect(owner).lend721(erc721.address, 1, erc20.address, 1, 100000, false);

        await erc20.mint(otherAccount.address, 100000);
        await erc20.connect(otherAccount).approve(market.address, 100000);
        await market.connect(otherAccount).rent(0);

        await time.increase(100000);

        await erc721.connect(otherAccount).approve(market.address, 1);
        await expect(market.connect(otherAccount).returnToken(0)).to.revertedWith("Already overtime");
      });
      it("Should be revert with no Returnable", async () => {
        const { owner, otherAccount, market, erc20, erc721 } = await loadFixture(deployFull);
        await erc721.mint(owner.address, 1);
        await erc721.approve(market.address, 1);
        await market.connect(owner).lend721(erc721.address, 1, erc20.address, 1, 100000, false);

        await erc20.mint(otherAccount.address, 100000);
        await erc20.connect(otherAccount).approve(market.address, 100000);
        await market.connect(otherAccount).rent(0);

        await expect(market.connect(otherAccount).returnToken(0)).to.revertedWith("Not returnable");
      });
    });
  });

  describe("Claim", () => {
    it("Should be claim after overtime", async () => {
      const { owner, otherAccount, market, erc20, erc721 } = await loadFixture(deployFull);
      await erc721.mint(owner.address, 1);
      await erc721.approve(market.address, 1);
      await market.connect(owner).lend721(erc721.address, 1, erc20.address, 1, 100000, false);

      await erc20.mint(otherAccount.address, 100000);
      await erc20.connect(otherAccount).approve(market.address, 100000);
      await market.connect(otherAccount).rent(0);

      await time.increase(100000);

      await expect(market.connect(owner).claim(0))
        .to.emit(erc20, "Transfer")
        .withArgs(market.address, owner.address, 95000)
        .to.emit(market, "RentClaimed")
        .withArgs(0, owner.address);

      expect(await erc20.balanceOf(owner.address)).to.equal(95000);
      expect(await erc20.balanceOf(market.address)).to.equal(5000);
    });
  });

  describe("Fee", () => {
    it("should be able to claim a fee", async () => {
      const { owner, otherAccount, market, erc20, erc721 } = await loadFixture(deployFull);
      await erc721.mint(owner.address, 1);
      await erc721.approve(market.address, 1);
      await market.connect(owner).lend721(erc721.address, 1, erc20.address, 1, 100000, false);

      await erc20.mint(otherAccount.address, 100000);
      await erc20.connect(otherAccount).approve(market.address, 100000);
      await market.connect(otherAccount).rent(0);

      await erc721.connect(otherAccount).approve(market.address, 1);
      await market.connect(otherAccount).returnToken(0);

      await expect(market.claimFee(erc20.address))
        .to.emit(market, "FeeClaimed")
        .withArgs(erc20.address, 4320)
        .to.emit(erc20, "Transfer")
        .withArgs(market.address, owner.address, 4320);
    });
  });
});
