// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "erc721a/contracts/ERC721A.sol";

contract CryptagendeGame is ERC721A, Ownable {
    // contract CryptagendeGame is ERC721A, Ownable, VRFConsumerBase {
    using Strings for uint256;
    using Strings for uint8;

    string _baseTokenURI =
        "https://cryptagende.mypinata.cloud/ipfs/QmcbyaahDpJkNPzsYuWWn7iMJNBzmdZ9igd7LWJD5jYFRH";
    // The amount of LINK to send with the request
    uint256 public fee;
    // ID of public key against which randomness is generated
    bytes32 public keyHash;

    // Set about the Whitelisted Person
    mapping(address => bool) whitelisted;
    uint256 public whitelistAddressCount;

    // Set Price
    uint256 public PUB_PRICE = 0.08 ether;
    uint256 public WHITELIST_PRICE = 0.064 ether;

    // Set Variable to start
    uint256 public startTime;
    bool public start;
    bool revealCard;

    // Amount of token which are mint
    uint256 public totalMinted = 0;

    // Level of each card
    mapping(uint256 => uint256) levelMapping;
    // Count of each level
    mapping(uint256 => uint256) idMapping;
    // Which card is selected
    mapping(uint256 => uint256) nameMapping;
    // Percent of each level
    mapping(uint256 => uint256) percentMapping;

    // Limits on each level
    uint256[8] private MAX_LIMIT = [0, 20, 400, 600, 1500, 3200, 3700, 5300];
    uint8[8] levelList = [0, 1, 2, 3, 4, 5, 6, 7];
    uint8 levelCount = 7;

    // address to receive pay
    address public authorizedWallet;

    /*
     * @dev
     *
     * @param vafCoordinator address of VRFCoordinator contract
     * @param linkToken address of LINK token contract
     * @param vrfkeyHash ID of public key against which randomness is generated
     * @param vrfFee The amount of LINK to send with the request
     */

    constructor(
        address vrfCoordinator,
        address linkToken,
        bytes32 vrfKeyHash,
        uint256 vrfFee
    )
        ERC721A("Cryptagende first season: battle of the gods", "BOB")
        VRFConsumerBase(vrfCoordinator, linkToken)
    {
        keyHash = vrfKeyHash;
        fee = vrfFee;
        percentMapping[0] = 0;
        percentMapping[1] = 1;
        percentMapping[2] = 36;
        percentMapping[3] = 90;
        percentMapping[4] = 240;
        percentMapping[5] = 440;
        percentMapping[6] = 650;
        percentMapping[7] = 1000;
        authorizedWallet = msg.sender;
    }

    /*
     * @dev fulfillRandomness handles the VRF response.
     *
     * @param requestId The Id initially returned by requestRandomness
     * @param randomness the VRF output
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        virtual
        override
    {}

    /*
     * @dev Choose random level and number for card
     *
     * @param id number of card
     */
    function selectRandomCard(uint256 id) private {
        bytes32 randbyte = getRandomNumber();
        uint256 rand = uint256(randbyte) % 1000;

        /*
            Find random level
        */
        for (uint8 i = 1; i <= levelCount; i++) {
            if (rand > percentMapping[i - 1] && rand <= percentMapping[i]) {
                randID = levelList[i];
            }
        }

        /*
            If 7th level card reaches its limit, choose 6th level card
        */
        if (randID == levelCount && idMapping[randID] >= MAX_LIMIT[randID]) {
            idMapping[randID - 1]++;
            levelMapping[totalMinted + id] = randID - 1;
            nameMapping[totalMinted + id] = idMapping[randID - 1];
            return;
        }

        /*
            Maximum control for each level
        */
        for (uint8 i = randID; i <= levelCount; i++) {
            if (idMapping[i] < MAX_LIMIT[i]) {
                idMapping[i]++;
                levelMapping[totalMinted + id] = i;
                nameMapping[totalMinted + id] = idMapping[i];
                break;
            }
        }
    }

    /*
     * @dev make transaction
     *
     * @param amount amount to mint
     */
    function mint(uint256 amount) public payable {
        require(start == true, "Sale has not start.");
        require(totalMinted + amount <= 8999, "Amount exceed");
        uint256 price;

        if (whitelisted[msg.sender]) {
            price = WHITELIST_PRICE * amount;
        } else {
            price = PUB_PRICE * amount;
        }

        require(msg.value >= price, "Incorrect Price");
        if (balanceOf(msg.sender) < 5 && balanceOf(msg.sender) + amount >= 5) {
            amount++;
        }
        _safeMint(msg.sender, amount);
        for (uint256 i = 0; i < amount; i++) {
            selectRandomCard(i);
        }
        payable(authorizedWallet).transfer(msg.value);
        totalMinted += amount;
    }

    /*
     * @dev sends request for random number to Chainlink VRF node along with fee
     *
     * @return returns random number
     */
    function getRandomNumber() private returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        return requestRandomness(keyHash, fee);
    }

    /*
     * @dev Set of price that other people mint
     *
     * @param price of public
     */
    function setPublicPrice(uint256 _pubPrice) external onlyOwner {
        PUB_PRICE = _pubPrice;
    }

    /*
     * @dev Set of price that people in whiteliste mint
     *
     * @param _wtlPrice price of whitelist
     */
    function setWhitelistedPrice(uint256 _wtlPrice) external onlyOwner {
        WHITELIST_PRICE = _wtlPrice;
    }

    /*
     * @dev open the marketplace
     */
    function startSale() external onlyOwner {
        require(start == false, "Sale is started!");
        startTime = block.timestamp;
        start = true;
    }

    /*
     * @dev add address in whitelisted
     *
     * @param addresses the addresses that add to whitelisted
     */
    function setWhitelistAddress(address[] calldata addresses)
        external
        onlyOwner
    {
        for (uint16 i = 0; i < addresses.length; i++) {
            whitelisted[addresses[i]] = true;
        }
        whitelistAddressCount += addresses.length;
    }

    /*
     * @dev find person who in whitelist
     *
     * @param address of who in whitelist
     *
     * @return
     */
    function findAddressInWhite(address user) external view returns (bool) {
        return whitelisted[user];
    }

    /*
     * @dev view the current card
     */
    function setReveal() external onlyOwner {
        revealCard = true;
    }

    /*
     * @dev view current token's metadata
     *
     * @param tokenId nonce id of token
     *
     * @return current token uri
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        if (!revealCard)
            return string(abi.encodePacked(_baseTokenURI, "/0.json"));
        else
            return
                string(
                    abi.encodePacked(
                        _baseTokenURI,
                        "/",
                        levelMapping[tokenId].toString(),
                        "/",
                        nameMapping[tokenId].toString(),
                        ".json"
                    )
                );
    }

    /*
     * @dev this functions to set the basicTokenURI
     *
     * @param _tokenURI
     */
    function setBaseURI(string memory _tokenURI) external onlyOwner {
        _baseTokenURI = _tokenURI;
    }

    /*
     * @dev Get current user mint count
     *
     * @param userAddress user's address
     *
     * @return number of mint transaction
     */
    function getMintcount(address userAddress)
        external
        view
        returns (uint256 count)
    {
        return balanceOf(userAddress);
    }

    /*
     * @dev Handing over management to someone
     *
     * @param adminAddress Someone's address
     */
    function setOwner(address adminAddress) external onlyOwner {
        _transferOwnership(adminAddress);
    }

    /*
     * @dev To send the amount of pay, you will set wallet address
     *
     * @param walletAddress The new wallet address that you will recieve pay
     */
    function setWallet(address walletAddress) external onlyOwner {
        authorizedWallet = walletAddress;
    }
}
