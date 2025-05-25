// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./GameVoting.sol";

interface IGameVoting {
    function upgradeTo(address newImplementation) external;
    function implementation() external view returns (address);
}

contract GameVotingAdmin is Ownable {
    address public gameVotingProxy;
    
    event ProxyDeployed(address proxy, address implementation);
    event ImplementationUpgraded(address newImplementation);
    
    constructor() Ownable(msg.sender) {}
    
    function deployProxy(address implementation) external onlyOwner {
        require(gameVotingProxy == address(0), "Proxy already deployed");
        
        bytes memory data = abi.encodeWithSelector(
            GameVoting(implementation).initialize.selector
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(
            implementation,
            data
        );
        
        gameVotingProxy = address(proxy);
        emit ProxyDeployed(address(proxy), implementation);
    }
    
    function upgradeImplementation(address newImplementation) external onlyOwner {
        require(gameVotingProxy != address(0), "Proxy not deployed");
        IGameVoting(gameVotingProxy).upgradeTo(newImplementation);
        emit ImplementationUpgraded(newImplementation);
    }
    
    function getImplementation() external view returns (address) {
        require(gameVotingProxy != address(0), "Proxy not deployed");
        return IGameVoting(gameVotingProxy).implementation();
    }
} 