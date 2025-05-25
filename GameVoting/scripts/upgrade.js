const { ethers } = require("hardhat");

async function main() {
    console.log("Starting upgrade process...");

    // Get the GameVotingAdmin contract
    const adminAddress = process.env.ADMIN_CONTRACT_ADDRESS;
    if (!adminAddress) {
        throw new Error("Please set ADMIN_CONTRACT_ADDRESS in your environment");
    }

    // Deploy new GameVoting implementation
    console.log("Deploying new GameVoting implementation...");
    const GameVoting = await ethers.getContractFactory("GameVoting");
    const newImplementation = await GameVoting.deploy();
    await newImplementation.waitForDeployment();
    const newImplementationAddress = await newImplementation.getAddress();
    console.log("New GameVoting implementation deployed to:", newImplementationAddress);

    // Get the admin contract
    const GameVotingAdmin = await ethers.getContractFactory("GameVotingAdmin");
    const admin = GameVotingAdmin.attach(adminAddress);

    // Upgrade to new implementation
    console.log("Upgrading proxy to new implementation...");
    const upgradeTx = await admin.upgrade(newImplementationAddress);
    await upgradeTx.wait();
    
    console.log("\nUpgrade Summary:");
    console.log("----------------");
    console.log("New Implementation:", newImplementationAddress);
    console.log("Admin Contract:", adminAddress);
    console.log("Proxy Address:", await admin.gameVotingProxy());
    console.log("\nUpgrade completed successfully!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 