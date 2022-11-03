import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
// import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

describe("EnglishAuction", function () {
  async function deployEnglishAuction() {
    const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
    const startAt = (await time.latest()) + ONE_YEAR_IN_SECS;
    const endAt = (await time.latest()) + ONE_YEAR_IN_SECS * 2;

    const [owner, acc1, acc2, acc3] = await ethers.getSigners();

    const Token = await ethers.getContractFactory("TokenERC20");
    const token = await Token.deploy();

    const Auction = await ethers.getContractFactory("EnglishAuction");
    const auction = await Auction.deploy();

    const NFT = await ethers.getContractFactory("TokenERC721");
    const nft = await NFT.deploy();

    return { auction, token, nft, owner, acc1, acc2, acc3, startAt, endAt };
  }

  describe("list asset", function () {
    it("Should list an asset correctly", async function () {
      const { token, auction, nft, owner, acc1, startAt, endAt } =
        await loadFixture(deployEnglishAuction);

      const assetID_1 = 1;

      await nft.connect(owner).safeMint(acc1.address, assetID_1);

      // await auction
      //   .connect(acc1.address)
      //   .listAsset(1, token.address, 10, startAt, endAt);

      // await expect(tx1)
      //   .to.emit(auction, "AssetListed")
      //   .withArgs(acc1.address, 1, 10, token.address);

      // expect(await lock.unlockTime()).to.equal(unlockTime);
    });
  });
});
