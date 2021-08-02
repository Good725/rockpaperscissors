
const hre = require("hardhat");

async function main() {
  const RockPaperScissors = await hre.ethers.getContractFactory("RockPaperScissors");
  const RockPaperScissorsContract = await RockPaperScissors.deploy();

  await RockPaperScissorsContract.deployed();

  console.log("RockPaperScissors deployed to:", RockPaperScissorsContract.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
