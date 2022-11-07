import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";

// import { connect } from "http2";

describe("EnglishAuction", function () {
  async function deployEnglishAuction() {
    const ONE_DAY_IN_SECS = 24 * 60 * 60;
    const TEN_DAYS_IN_SECS = 10 * 24 * 60 * 60;
    const startAt = (await time.latest()) + ONE_DAY_IN_SECS;
    const endAt = (await time.latest()) + TEN_DAYS_IN_SECS;

    const [owner, acc1, acc2, acc3] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("TokenERC20");
    const token = await Token.deploy();

    const NFT = await ethers.getContractFactory("TokenERC721");
    const nft = await NFT.deploy();

    const Auction = await ethers.getContractFactory("EnglishAuction");
    const auction = await Auction.deploy();

    return { auction, token, nft, owner, acc1, acc2, acc3, startAt, endAt };
  }

  // beforeEach(async function () {});

  it("Should not bid on auction correctly", async function () {
    const { token, auction, nft, owner, acc1, acc2, startAt, endAt } =
      await loadFixture(deployEnglishAuction);

    const assetID_1 = 1;

    await nft.connect(owner).safeMint(acc1.address, assetID_1);
    await nft.connect(acc1).approve(auction.address, assetID_1);

    await token.increaseAllowance(auction.address, 100);
    await token.increaseAllowance(acc2.address, 100);

    await token.connect(owner).mint(acc2.address, 100);

    await token.connect(acc2).approve(auction.address, 100);

    await expect(
      auction
        .connect(acc1)
        .listAsset(assetID_1, token.address, nft.address, 10, startAt, endAt)
    )
      .to.emit(auction, "AssetListed")
      .withArgs(acc1.address, assetID_1, 10, token.address);

    await time.increaseTo(endAt + 24 * 60 * 60);

    await expect(
      auction.connect(acc2).placeBid(assetID_1, 100)
    ).to.be.revertedWith("auction ended");
  });

  describe("list asset", function () {
    it("Should bid and win auction correctly", async function () {
      const { token, auction, nft, owner, acc1, acc2, startAt, endAt } =
        await loadFixture(deployEnglishAuction);

      const assetID_1 = 1;

      await nft.connect(owner).safeMint(acc1.address, assetID_1);
      await nft.connect(acc1).approve(auction.address, assetID_1);

      await token.increaseAllowance(auction.address, 100);
      await token.increaseAllowance(acc2.address, 100);

      await token.connect(owner).mint(acc2.address, 100);

      await token.connect(acc2).approve(auction.address, 100);

      await expect(
        auction
          .connect(acc1)
          .listAsset(
            assetID_1,
            token.address,
            nft.address,
            10,
            await time.latest(),
            endAt
          )
      ).to.be.revertedWith("future start only");

      await expect(
        auction
          .connect(acc1)
          .listAsset(assetID_1, token.address, nft.address, 10, endAt, startAt)
      ).to.be.revertedWith("ends after starts only");

      await expect(
        auction
          .connect(acc2)
          .listAsset(assetID_1, token.address, nft.address, 10, startAt, endAt)
      ).to.be.revertedWith("only owner");

      await expect(
        auction
          .connect(acc1)
          .listAsset(
            assetID_1,
            token.address,
            token.address,
            10,
            startAt,
            endAt
          )
      ).to.be.revertedWith("not an ERC721");

      await expect(
        auction
          .connect(acc1)
          .listAsset(assetID_1, token.address, nft.address, 10, startAt, endAt)
      )
        .to.emit(auction, "AssetListed")
        .withArgs(acc1.address, assetID_1, 10, token.address);

      await expect(
        auction.connect(acc2).placeBid(assetID_1, 100)
      ).to.be.revertedWith("auction yet to start");

      await time.increaseTo(startAt);

      await expect(auction.connect(acc2).placeBid(assetID_1, 100))
        .to.emit(auction, "Bid")
        .withArgs(acc2.address, assetID_1, 100, token.address);

      await expect(
        auction.connect(owner).finishAuction(assetID_1)
      ).to.be.revertedWith("auction in progress");

      await expect(auction.connect(owner).finishAuction(2)).to.be.revertedWith(
        "non listed asset"
      );

      await time.increaseTo(endAt);

      await expect(auction.connect(owner).finishAuction(assetID_1))
        .to.emit(auction, "Sale")
        .withArgs(assetID_1, acc2.address, 100, token.address);
    });

    it("Should bid below min auction correctly", async function () {
      const { token, auction, nft, owner, acc1, acc2, startAt, endAt } =
        await loadFixture(deployEnglishAuction);

      const assetID_1 = 1;

      await nft.connect(owner).safeMint(acc1.address, assetID_1);
      await nft.connect(acc1).approve(auction.address, assetID_1);

      await token.increaseAllowance(auction.address, 100);
      await token.increaseAllowance(acc2.address, 100);

      await token.connect(owner).mint(acc2.address, 100);

      await token.connect(acc2).approve(auction.address, 100);

      await expect(
        auction
          .connect(acc1)
          .listAsset(assetID_1, token.address, nft.address, 100, startAt, endAt)
      )
        .to.emit(auction, "AssetListed")
        .withArgs(acc1.address, assetID_1, 100, token.address);

      await expect(
        auction.connect(acc2).placeBid(assetID_1, 50)
      ).to.be.revertedWith("auction yet to start");

      await time.increaseTo(startAt);

      await expect(
        auction.connect(acc2).placeBid(assetID_1, 50)
      ).to.be.revertedWith("min bid is higher");

      await time.increaseTo(endAt);

      await expect(auction.connect(owner).finishAuction(assetID_1))
        .to.emit(auction, "Withdraw")
        .withArgs(assetID_1, acc1.address);
    });

    it("Should bid and loose auction correctly", async function () {
      const { token, auction, nft, owner, acc1, acc2, acc3, startAt, endAt } =
        await loadFixture(deployEnglishAuction);

      const assetID_1 = 1;

      await nft.connect(owner).safeMint(acc1.address, assetID_1);
      await nft.connect(acc1).approve(auction.address, assetID_1);

      await token.increaseAllowance(auction.address, 100);
      await token.increaseAllowance(acc2.address, 100);
      await token.increaseAllowance(acc3.address, 100);

      await token.connect(owner).mint(acc2.address, 100);
      await token.connect(owner).mint(acc3.address, 100);

      await token.connect(acc2).approve(auction.address, 100);
      await token.connect(acc3).approve(auction.address, 100);

      await expect(
        auction
          .connect(acc1)
          .listAsset(assetID_1, token.address, nft.address, 10, startAt, endAt)
      )
        .to.emit(auction, "AssetListed")
        .withArgs(acc1.address, assetID_1, 10, token.address);

      await expect(
        auction.connect(acc2).placeBid(assetID_1, 50)
      ).to.be.revertedWith("auction yet to start");

      await time.increaseTo(startAt);

      await expect(auction.connect(acc2).placeBid(assetID_1, 50))
        .to.emit(auction, "Bid")
        .withArgs(acc2.address, assetID_1, 50, token.address);

      await expect(
        auction.connect(acc3).placeBid(assetID_1, 50)
      ).to.be.revertedWith("last bid is higher");

      await expect(auction.connect(acc3).placeBid(assetID_1, 100))
        .to.emit(auction, "BidReturn")
        .withArgs(acc2.address, assetID_1, 50, token.address);

      await time.increaseTo(endAt);

      await expect(auction.connect(owner).finishAuction(assetID_1))
        .to.emit(auction, "Sale")
        .withArgs(assetID_1, acc3.address, 100, token.address);

      await expect(
        auction.connect(acc2).placeBid(assetID_1, 50)
      ).to.be.revertedWith("asset not listed");
    });
  });
});
