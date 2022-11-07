import { ethers } from "hardhat";

async function main() {
  const CONTRACT = await ethers.getContractFactory("TokenERC20");
  const contract = await CONTRACT.deploy();

  await contract.deployed();

  console.log("TokenERC20 deployed to:", contract.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
