import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

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

  describe("list asset", function () {
    it("Should list an asset correctly", async function () {
      const { token, auction, nft, owner, acc1, startAt, endAt } =
        await loadFixture(deployEnglishAuction);

      const assetID_1 = 1;

      await nft.connect(owner).safeMint(acc1.address, assetID_1);

      expect(
        await auction
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
        await auction
          .connect(acc1)
          .listAsset(assetID_1, token.address, nft.address, 10, startAt, endAt)
      ).to.be.revertedWith("ERC721: caller is not token owner nor approved");

      console.log(nft.address);

      await nft.connect(owner).transferOwnership(acc1.address);

      const listAssetTX = await auction
        .connect(acc1)
        .listAsset(assetID_1, token.address, nft.address, 10, startAt, endAt);

      await expect(listAssetTX)
        .to.emit(auction, "TransferReceivedNFT")
        .withArgs(acc1.address, assetID_1);

      await expect(listAssetTX)
        .to.emit(auction, "AssetListed")
        .withArgs(acc1.address, 1, 10, token.address);
    });
  });
});
