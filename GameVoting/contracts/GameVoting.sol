// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title GameVoting
 * @dev A smart contract for managing game voting campaigns with daily voting mechanics and winner selection
 * @notice This contract allows users to vote for games in campaigns once per day and enables fair winner selection
 * @author BAG Guild Team
 */
contract GameVoting is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    
    // =============================================================
    //                           ENUMS & STRUCTS
    // =============================================================
    
    /// @dev Prize types available for games
    enum PrizeType { CASH, NFT, BOTH }
    
    /// @dev Game information structure
    struct Game {
        string name;
        string description;
        string imageUrl;
        string bannerUrl;
        uint256 voteCount;
        uint256 totalPrizes;
        uint256 playCount;
        PrizeType prizeType;
        bool exists;
    }
    
    /// @dev Campaign game structure with votes and prizes
    struct CampaignGame {
        uint256 gameId;
        uint256 voteCount;
        string gamePrizes;
    }
    
    /// @dev Voting campaign structure
    struct VotingCampaign {
        string name;
        string description;
        CampaignGame[] campaignGames;
        uint256 startTime;
        uint256 endTime;
        address[] winners;
        bool winnersDrawn;
    }

    /// @dev Campaign game details for frontend display
    struct CampaignGameDetails {
        uint256 gameId;
        string name;
        string imageUrl;
        uint256 voteCount;
        string gamePrizes;
        PrizeType prizeType;
    }
    
    // =============================================================
    //                        STATE VARIABLES
    // =============================================================
    
    /// @dev Contract version for upgrades
    uint256 public constant VERSION = 1;
    
    /// @dev Mapping of game IDs to game information
    mapping(uint256 => Game) public games;
    /// @dev Total number of games created
    uint256 public gameCount;
    
    /// @dev Mapping of campaign IDs to campaign information
    mapping(uint256 => VotingCampaign) public votingCampaigns;
    /// @dev Total number of campaigns created
    uint256 public campaignCount;
    
    // Voting tracking mappings
    /// @dev Maps user to campaign to last voted day
    mapping(address => mapping(uint256 => uint256)) public lastVotedDay;
    /// @dev Total votes per user per campaign
    mapping(address => mapping(uint256 => uint256)) public totalVotesInCampaign;
    /// @dev Daily votes per user per campaign per game
    mapping(address => mapping(uint256 => mapping(uint256 => uint256))) public dailyVotesForGame;
    /// @dev Track voters for each game in each campaign
    mapping(uint256 => mapping(uint256 => address[])) private gameVoters;
    /// @dev Track if user has voted for a game in campaign (to avoid duplicates in array)
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) private hasVotedForGameTracker;
    
    // Legacy mappings for backward compatibility
    /// @dev Legacy: Check if user has voted in campaign
    mapping(address => mapping(uint256 => bool)) public hasVotedInCampaign;
    /// @dev Legacy: Check if user has voted for specific game in campaign
    mapping(address => mapping(uint256 => mapping(uint256 => bool))) public hasVotedForGameInCampaign;
    
    // =============================================================
    //                             EVENTS
    // =============================================================
    
    /// @dev Emitted when a new game is added
    event GameAdded(uint256 indexed gameId, string name, PrizeType prizeType);
    /// @dev Emitted when a user votes for a game
    event VoteCasted(uint256 indexed campaignId, uint256 indexed gameId, address indexed voter, uint256 day);
    /// @dev Emitted when a new voting campaign is created
    event VotingCampaignCreated(uint256 indexed campaignId, string name, uint256 endTime);
    /// @dev Emitted when a game is updated
    event GameUpdated(uint256 indexed gameId, string name);
    /// @dev Emitted when winners are drawn for a campaign
    event WinnersDrawn(uint256 indexed campaignId, address[] winners, uint256 winningGameId);
    
    // =============================================================
    //                           MODIFIERS
    // =============================================================
    
    /**
     * @dev Modifier to check if campaign is currently active
     * @param _campaignId The ID of the campaign to check
     */
    modifier campaignActive(uint256 _campaignId) {
        require(block.timestamp >= votingCampaigns[_campaignId].startTime, "Voting campaign has not started yet");
        require(block.timestamp <= votingCampaigns[_campaignId].endTime, "Voting campaign has ended");
        _;
    }
    
    /**
     * @dev Modifier to check if campaign has ended
     * @param _campaignId The ID of the campaign to check
     */
    modifier campaignEnded(uint256 _campaignId) {
        require(block.timestamp > votingCampaigns[_campaignId].endTime, "Voting campaign has not ended yet");
        _;
    }
    
    // =============================================================
    //                        INITIALIZATION
    // =============================================================
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @dev Initialize the contract
     * @notice Sets up the contract with initial values
     */
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        gameCount = 0;
        campaignCount = 0;
    }

    /**
     * @dev Authorize contract upgrades
     * @param newImplementation Address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override view onlyOwner {
        require(newImplementation != address(0), "Invalid implementation address");
    }
    
    // =============================================================
    //                         ADMIN FUNCTIONS
    // =============================================================
    
    /**
     * @dev Add a new game to the platform
     * @param _name Name of the game
     * @param _description Description of the game
     * @param _imageUrl URL of the game image
     * @param _bannerUrl URL of the game banner
     * @param _prizeType Type of prizes for the game
     * @notice Only owner can add games
     */
    function addGame(
        string memory _name, 
        string memory _description, 
        string memory _imageUrl,
        string memory _bannerUrl,
        PrizeType _prizeType
    ) public onlyOwner {
        gameCount++;
        games[gameCount] = Game({
            name: _name,
            description: _description,
            imageUrl: _imageUrl,
            bannerUrl: _bannerUrl,
            voteCount: 0,
            totalPrizes: 0,
            playCount: 0,
            prizeType: _prizeType,
            exists: true
        });
        
        emit GameAdded(gameCount, _name, _prizeType);
    }
    
    /**
     * @dev Update existing game details
     * @param _gameId ID of the game to update
     * @param _name New name of the game
     * @param _description New description of the game
     * @param _imageUrl New image URL
     * @param _bannerUrl New banner URL
     * @param _voteCount New vote count
     * @param _totalPrizes New total prizes
     * @param _playCount New play count
     * @param _prizeType New prize type
     * @notice Only owner can update games
     */
    function updateGame(
        uint256 _gameId, 
        string memory _name, 
        string memory _description, 
        string memory _imageUrl,
        string memory _bannerUrl,
        uint256 _voteCount,
        uint256 _totalPrizes,
        uint256 _playCount,
        PrizeType _prizeType
    ) public onlyOwner {
        require(games[_gameId].exists, "Game does not exist");
        
        Game storage game = games[_gameId];
        game.name = _name;
        game.description = _description;
        game.imageUrl = _imageUrl;
        game.bannerUrl = _bannerUrl;
        game.voteCount = _voteCount;
        game.totalPrizes = _totalPrizes;
        game.playCount = _playCount;
        game.prizeType = _prizeType;
        
        emit GameUpdated(_gameId, _name);
    }
    
    /**
     * @dev Create a new voting campaign
     * @param _name Name of the campaign
     * @param _description Description of the campaign
     * @param _gameIds Array of game IDs to include in campaign
     * @param _gamePrizes Array of prize descriptions for each game
     * @param _startTime Campaign start timestamp
     * @param _endTime Campaign end timestamp
     * @notice Only owner can create campaigns
     */
    function createVotingCampaign(
        string memory _name,
        string memory _description,
        uint256[] memory _gameIds, 
        string[] memory _gamePrizes,
        uint256 _startTime, 
        uint256 _endTime
    ) public onlyOwner {
        require(_endTime > _startTime, "End time must be after start time");
        require(_gameIds.length > 0, "Must include at least one game");
        require(_gameIds.length == _gamePrizes.length, "Game IDs and prizes arrays must be the same length");
        
        campaignCount++;
        VotingCampaign storage newCampaign = votingCampaigns[campaignCount];
        newCampaign.name = _name;
        newCampaign.description = _description;
        newCampaign.startTime = _startTime;
        newCampaign.endTime = _endTime;
        
        // Populate campaign games
        for (uint256 i = 0; i < _gameIds.length; i++) {
            uint256 gameId = _gameIds[i];
            require(games[gameId].exists, "One of the games does not exist");
            
            newCampaign.campaignGames.push(CampaignGame({
                gameId: gameId,
                voteCount: 0,
                gamePrizes: _gamePrizes[i]
            }));
        }
        
        emit VotingCampaignCreated(campaignCount, _name, _endTime);
    }
    
    /**
     * @dev Draw winners from a completed campaign
     * @param _campaignId ID of the campaign to draw winners from
     * @param _numberOfWinners Number of winners to select
     * @notice Only owner can draw winners after campaign ends
     * @notice Winners are selected from voters of the winning game using weighted random selection
     */
    function drawWinners(uint256 _campaignId, uint256 _numberOfWinners) public onlyOwner campaignEnded(_campaignId) {
        require(_numberOfWinners > 0, "Number of winners must be greater than 0");
        require(!votingCampaigns[_campaignId].winnersDrawn, "Winners already drawn for this campaign");
        
        // Find the winning game (game with most votes)
        uint256 winningGameId = getWinningGame(_campaignId);
        require(winningGameId != 0, "No winning game found");
        
        // Get all voters for the winning game
        address[] memory eligibleVoters = getVotersForGame(_campaignId, winningGameId);
        require(eligibleVoters.length > 0, "No voters found for winning game");
        
        // Ensure we don't draw more winners than eligible voters
        uint256 actualNumberOfWinners = _numberOfWinners > eligibleVoters.length ? eligibleVoters.length : _numberOfWinners;
        
        // Draw winners using weighted random selection
        address[] memory winners = drawWeightedRandomWinners(_campaignId, winningGameId, eligibleVoters, actualNumberOfWinners);
        
        // Store winners in campaign
        votingCampaigns[_campaignId].winners = winners;
        votingCampaigns[_campaignId].winnersDrawn = true;
        
        emit WinnersDrawn(_campaignId, winners, winningGameId);
    }
    
    // =============================================================
    //                        VOTING FUNCTIONS
    // =============================================================
    
    /**
     * @dev Vote for a game in an active campaign
     * @param _campaignId ID of the campaign
     * @param _gameId ID of the game to vote for
     * @notice Users can vote once per day during the campaign period
     * @notice Game must be part of the specified campaign
     */
    function voteForGame(uint256 _campaignId, uint256 _gameId) public campaignActive(_campaignId) {
        require(canVoteToday(msg.sender, _campaignId), "Already voted today in this campaign");
        
        VotingCampaign storage campaign = votingCampaigns[_campaignId];
        bool gameFound = false;
        uint256 gameIndex = 0;
        
        // Find the game in the campaign
        for (uint256 i = 0; i < campaign.campaignGames.length; i++) {
            if (campaign.campaignGames[i].gameId == _gameId) {
                gameFound = true;
                gameIndex = i;
                break;
            }
        }
        
        require(gameFound, "Game is not part of this voting campaign");
        
        uint256 currentDay = getCurrentDay();
        
        // Record the vote in the campaign
        campaign.campaignGames[gameIndex].voteCount++;
        
        // Also record the vote in the main game storage
        games[_gameId].voteCount++;
        
        // Update voting tracking
        lastVotedDay[msg.sender][_campaignId] = currentDay;
        totalVotesInCampaign[msg.sender][_campaignId]++;
        dailyVotesForGame[msg.sender][_campaignId][_gameId]++;
        
        // Track voter for this game if first time voting for this game
        if (!hasVotedForGameTracker[_campaignId][_gameId][msg.sender]) {
            gameVoters[_campaignId][_gameId].push(msg.sender);
            hasVotedForGameTracker[_campaignId][_gameId][msg.sender] = true;
        }
        
        // Mark as voted (for backward compatibility)
        hasVotedForGameInCampaign[msg.sender][_campaignId][_gameId] = true;
        hasVotedInCampaign[msg.sender][_campaignId] = true;
        
        emit VoteCasted(_campaignId, _gameId, msg.sender, currentDay);
    }
    
    // =============================================================
    //                           VIEW FUNCTIONS
    // =============================================================
    
    /**
     * @dev Get details of a specific game
     * @param _gameId ID of the game to retrieve
     * @return name Name of the game
     * @return description Description of the game
     * @return imageUrl Image URL of the game
     * @return bannerUrl Banner URL of the game
     * @return voteCount Total votes received by the game
     * @return totalPrizes Total prizes for the game
     * @return playCount Number of times the game has been played
     * @return prizeType Type of prizes for the game
     */
    function getGame(uint256 _gameId) public view returns (
        string memory name,
        string memory description,
        string memory imageUrl,
        string memory bannerUrl,
        uint256 voteCount,
        uint256 totalPrizes,
        uint256 playCount,
        PrizeType prizeType
    ) {
        require(games[_gameId].exists, "Game does not exist");
        Game memory game = games[_gameId];
        
        return (
            game.name,
            game.description,
            game.imageUrl,
            game.bannerUrl,
            game.voteCount,
            game.totalPrizes,
            game.playCount,
            game.prizeType
        );
    }
    
    /**
     * @dev Get details of a specific campaign with all games
     * @param _campaignId ID of the campaign to retrieve
     * @return campaignName Name of the campaign
     * @return campaignDescription Description of the campaign
     * @return campaignStartTime Start timestamp of the campaign
     * @return campaignEndTime End timestamp of the campaign
     * @return campaignActive Whether the campaign is currently active
     * @return gameDetails Array of game details in the campaign
     */
    function getCampaign(uint256 _campaignId) public view returns (
        string memory campaignName,
        string memory campaignDescription,
        uint256 campaignStartTime,
        uint256 campaignEndTime,
        bool campaignActive,
        CampaignGameDetails[] memory gameDetails
    ) {
        VotingCampaign storage campaign = votingCampaigns[_campaignId];
        campaignActive = block.timestamp >= campaign.startTime && block.timestamp <= campaign.endTime;
        
        // Create array to hold game details
        CampaignGameDetails[] memory gameDetailsArray = new CampaignGameDetails[](campaign.campaignGames.length);
        
        // Populate game details
        for (uint256 i = 0; i < campaign.campaignGames.length; i++) {
            CampaignGame storage campaignGame = campaign.campaignGames[i];
            Game storage game = games[campaignGame.gameId];
            
            gameDetailsArray[i] = CampaignGameDetails({
                gameId: campaignGame.gameId,
                name: game.name,
                imageUrl: game.imageUrl,
                voteCount: campaignGame.voteCount,
                gamePrizes: campaignGame.gamePrizes,
                prizeType: game.prizeType
            });
        }
        
        return (
            campaign.name,
            campaign.description,
            campaign.startTime,
            campaign.endTime,
            campaignActive,
            gameDetailsArray
        );
    }
    
    /**
     * @dev Get all existing game IDs
     * @return Array of game IDs
     */
    function getAllGames() public view returns (uint256[] memory) {
        uint256[] memory allGameIds = new uint256[](gameCount);
        uint256 counter = 0;
        
        for (uint256 i = 1; i <= gameCount; i++) {
            if (games[i].exists) {
                allGameIds[counter] = i;
                counter++;
            }
        }
        
        // Create a correctly sized array if there were deleted games
        if (counter < gameCount) {
            uint256[] memory result = new uint256[](counter);
            for (uint256 i = 0; i < counter; i++) {
                result[i] = allGameIds[i];
            }
            return result;
        }
        
        return allGameIds;
    }
    
    /**
     * @dev Get all currently active campaign IDs
     * @return Array of active campaign IDs
     */
    function getActiveCampaigns() public view returns (uint256[] memory) {
        uint256[] memory activeCampaignIds = new uint256[](campaignCount);
        uint256 counter = 0;
        
        for (uint256 i = 1; i <= campaignCount; i++) {
            if (block.timestamp >= votingCampaigns[i].startTime && 
                block.timestamp <= votingCampaigns[i].endTime) {
                activeCampaignIds[counter] = i;
                counter++;
            }
        }
        
        // Create a correctly sized array
        uint256[] memory result = new uint256[](counter);
        for (uint256 i = 0; i < counter; i++) {
            result[i] = activeCampaignIds[i];
        }
        
        return result;
    }
    
    /**
     * @dev Get all completed campaign IDs
     * @return Array of completed campaign IDs
     */
    function getCompletedCampaigns() public view returns (uint256[] memory) {
        uint256[] memory completedCampaignIds = new uint256[](campaignCount);
        uint256 counter = 0;
        
        for (uint256 i = 1; i <= campaignCount; i++) {
            if (block.timestamp > votingCampaigns[i].endTime) {
                completedCampaignIds[counter] = i;
                counter++;
            }
        }
        
        // Create a correctly sized array
        uint256[] memory result = new uint256[](counter);
        for (uint256 i = 0; i < counter; i++) {
            result[i] = completedCampaignIds[i];
        }
        
        return result;
    }
    
    /**
     * @dev Get all upcoming campaign IDs (not started yet)
     * @return Array of upcoming campaign IDs
     */
    function getUpcomingCampaigns() public view returns (uint256[] memory) {
        uint256[] memory upcomingCampaignIds = new uint256[](campaignCount);
        uint256 counter = 0;
        
        for (uint256 i = 1; i <= campaignCount; i++) {
            if (block.timestamp < votingCampaigns[i].startTime) {
                upcomingCampaignIds[counter] = i;
                counter++;
            }
        }
        
        // Create a correctly sized array
        uint256[] memory result = new uint256[](counter);
        for (uint256 i = 0; i < counter; i++) {
            result[i] = upcomingCampaignIds[i];
        }
        
        return result;
    }

    /**
     * @dev Get current day (days since Unix epoch)
     * @return Current day number
     */
    function getCurrentDay() public view returns (uint256) {
        return block.timestamp / 86400; // 86400 seconds = 24 hours
    }
    
    /**
     * @dev Check if user can vote today in a specific campaign
     * @param _voter Address of the voter
     * @param _campaignId ID of the campaign
     * @return True if user can vote today, false otherwise
     */
    function canVoteToday(address _voter, uint256 _campaignId) public view returns (bool) {
        uint256 currentDay = getCurrentDay();
        return lastVotedDay[_voter][_campaignId] < currentDay;
    }
    
    /**
     * @dev Get user's total votes in a campaign
     * @param _voter Address of the voter
     * @param _campaignId ID of the campaign
     * @return Total number of votes by the user in the campaign
     */
    function getUserTotalVotes(address _voter, uint256 _campaignId) public view returns (uint256) {
        return totalVotesInCampaign[_voter][_campaignId];
    }
    
    /**
     * @dev Get user's votes for a specific game in a campaign
     * @param _voter Address of the voter
     * @param _campaignId ID of the campaign
     * @param _gameId ID of the game
     * @return Number of votes by the user for the specific game
     */
    function getUserVotesForGame(address _voter, uint256 _campaignId, uint256 _gameId) public view returns (uint256) {
        return dailyVotesForGame[_voter][_campaignId][_gameId];
    }
    
    /**
     * @dev Get user's last voted day in a campaign
     * @param _voter Address of the voter
     * @param _campaignId ID of the campaign
     * @return Last day the user voted in the campaign
     */
    function getUserLastVotedDay(address _voter, uint256 _campaignId) public view returns (uint256) {
        return lastVotedDay[_voter][_campaignId];
    }
    
    /**
     * @dev Get the winning game of a campaign (game with most votes)
     * @param _campaignId ID of the campaign
     * @return ID of the winning game
     */
    function getWinningGame(uint256 _campaignId) public view returns (uint256) {
        VotingCampaign storage campaign = votingCampaigns[_campaignId];
        uint256 maxVotes = 0;
        uint256 winningGameId = 0;
        
        for (uint256 i = 0; i < campaign.campaignGames.length; i++) {
            if (campaign.campaignGames[i].voteCount > maxVotes) {
                maxVotes = campaign.campaignGames[i].voteCount;
                winningGameId = campaign.campaignGames[i].gameId;
            }
        }
        
        return winningGameId;
    }
    
    /**
     * @dev Get all voters for a specific game in a campaign
     * @param _campaignId ID of the campaign
     * @param _gameId ID of the game
     * @return Array of voter addresses
     */
    function getVotersForGame(uint256 _campaignId, uint256 _gameId) public view returns (address[] memory) {
        return gameVoters[_campaignId][_gameId];
    }
    
    /**
     * @dev Get number of unique voters for a specific game in a campaign
     * @param _campaignId ID of the campaign
     * @param _gameId ID of the game
     * @return Number of unique voters
     */
    function getVoterCountForGame(uint256 _campaignId, uint256 _gameId) public view returns (uint256) {
        return gameVoters[_campaignId][_gameId].length;
    }
    
    /**
     * @dev Check if user has voted for a specific game in a campaign
     * @param _campaignId ID of the campaign
     * @param _gameId ID of the game
     * @param _user Address of the user
     * @return True if user has voted for the game, false otherwise
     */
    function hasUserVotedForGame(uint256 _campaignId, uint256 _gameId, address _user) public view returns (bool) {
        return hasVotedForGameTracker[_campaignId][_gameId][_user];
    }
    
    /**
     * @dev Get winners of a specific campaign
     * @param _campaignId ID of the campaign
     * @return Array of winner addresses
     */
    function getCampaignWinners(uint256 _campaignId) public view returns (address[] memory) {
        return votingCampaigns[_campaignId].winners;
    }
    
    /**
     * @dev Check if winners have been drawn for a campaign
     * @param _campaignId ID of the campaign
     * @return True if winners have been drawn, false otherwise
     */
    function areWinnersDrawn(uint256 _campaignId) public view returns (bool) {
        return votingCampaigns[_campaignId].winnersDrawn;
    }
    
    // =============================================================
    //                        INTERNAL FUNCTIONS
    // =============================================================
    
    /**
     * @dev Weighted random winner selection based on vote count
     * @param _campaignId ID of the campaign
     * @param _gameId ID of the game
     * @param _eligibleVoters Array of eligible voter addresses
     * @param _numberOfWinners Number of winners to select
     * @return Array of selected winner addresses
     * @notice Uses pseudo-random selection weighted by vote count
     * @notice For production, consider using Chainlink VRF for true randomness
     */
    function drawWeightedRandomWinners(
        uint256 _campaignId, 
        uint256 _gameId, 
        address[] memory _eligibleVoters, 
        uint256 _numberOfWinners
    ) internal view returns (address[] memory) {
        address[] memory winners = new address[](_numberOfWinners);
        address[] memory remainingVoters = new address[](_eligibleVoters.length);
        
        // Copy eligible voters to working array
        for (uint256 i = 0; i < _eligibleVoters.length; i++) {
            remainingVoters[i] = _eligibleVoters[i];
        }
        
        uint256 remainingVotersCount = _eligibleVoters.length;
        
        for (uint256 winnerIndex = 0; winnerIndex < _numberOfWinners; winnerIndex++) {
            if (remainingVotersCount == 0) break;
            
            // Calculate total weighted votes for remaining voters
            uint256 totalWeightedVotes = 0;
            for (uint256 i = 0; i < remainingVotersCount; i++) {
                totalWeightedVotes += getUserVotesForGame(remainingVoters[i], _campaignId, _gameId);
            }
            
            // Generate random number based on total weighted votes
            uint256 randomValue = generateRandomNumber(totalWeightedVotes, winnerIndex);
            
            // Find winner based on weighted selection
            uint256 currentWeight = 0;
            address selectedWinner;
            uint256 selectedIndex = 0;
            
            for (uint256 i = 0; i < remainingVotersCount; i++) {
                currentWeight += getUserVotesForGame(remainingVoters[i], _campaignId, _gameId);
                if (randomValue <= currentWeight) {
                    selectedWinner = remainingVoters[i];
                    selectedIndex = i;
                    break;
                }
            }
            
            winners[winnerIndex] = selectedWinner;
            
            // Remove selected winner from remaining voters
            for (uint256 i = selectedIndex; i < remainingVotersCount - 1; i++) {
                remainingVoters[i] = remainingVoters[i + 1];
            }
            remainingVotersCount--;
        }
        
        return winners;
    }
    
    /**
     * @dev Generate pseudo-random number
     * @param _max Maximum value for the random number
     * @param _nonce Additional entropy for randomness
     * @return Pseudo-random number between 1 and _max
     * @notice This is not truly random and should not be used in production
     * @notice For production, consider using Chainlink VRF or similar oracle service
     */
    function generateRandomNumber(uint256 _max, uint256 _nonce) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, _nonce))) % _max + 1;
    }
}