const { ethers } = require("hardhat");

async function main() {
    console.log("Starting deployment...");

    // Deploy GameVoting implementation
    console.log("Deploying GameVoting implementation...");
    const GameVoting = await ethers.getContractFactory("GameVoting");
    const gameVoting = await GameVoting.deploy();
    await gameVoting.waitForDeployment();
    const implementationAddress = await gameVoting.getAddress();
    console.log("GameVoting implementation deployed to:", implementationAddress);

    // Deploy GameVotingAdmin
    console.log("Deploying GameVotingAdmin...");
    const GameVotingAdmin = await ethers.getContractFactory("GameVotingAdmin");
    const admin = await GameVotingAdmin.deploy();
    await admin.waitForDeployment();
    const adminAddress = await admin.getAddress();
    console.log("GameVotingAdmin deployed to:", adminAddress);

    // Deploy Proxy through Admin
    console.log("Deploying Proxy through Admin...");
    const deployTx = await admin.deployProxy(implementationAddress);
    await deployTx.wait();
    
    // Get proxy address
    const proxyAddress = await admin.gameVotingProxy();
    console.log("Proxy deployed to:", proxyAddress);

    console.log("\nDeployment Summary:");
    console.log("-------------------");
    console.log("Implementation:", implementationAddress);
    console.log("Admin:", adminAddress);
    console.log("Proxy:", proxyAddress);
    console.log("\nTo interact with the contract, use the proxy address with the GameVoting ABI");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 