import { ethers } from "hardhat";

async function main() {
  const CONTRACT = await ethers.getContractFactory("EnglishAuction");
  const contract = await CONTRACT.deploy();

  await contract.deployed();

  console.log("EnglishAuction deployed to:", contract.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
