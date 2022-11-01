// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface ITest {
    function isERC1155(address nftAddress) external returns (bool);

    function isERC721(address nftAddress) external returns (bool);
}

contract EnglishAuction is
    IERC721Receiver,
    ERC721URIStorage,
    Ownable,
    ReentrancyGuard
{
    struct ListedToken {
        uint256 ID;
        address payable seller;
        address payable owner;
        uint256 endAt;
        uint256 startAt;
        address highestBidder;
        uint highestBid;
        mapping(address => uint256) bids;
        uint256 bidsCount;
        uint256 price;
        string currrency;
        address ERC20;
        address NFT;
        bool listed;
    }

    // ****************** EVENTS ******************
    event Start();
    event Bid(address indexed sender, uint amount);
    event Withdraw(address indexed bidder, uint amount);
    event End(address winner, uint amount);

    // ****************** VARS ******************

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIDs;
    Counters.Counter private _itemsSold;
    address payable contractsOwner;
    uint256 adminFee = 0.01 ether;

    mapping(uint256 => ListedToken) private idToListedToken;

    constructor() ERC721("EnglishAuction", "EAU") {
        contractsOwner = payable(msg.sender);
    }

    // ****************** PUBLIC FUNCTIONS ******************

    /**
     * ERC721TokenReceiver interface function. Hook that will be triggered on safeTransferFrom as per EIP-721.
     * It should execute a deposit for `_from` address.
     * After deposit this token can be either returned back to the owner, or placed on auction.
     * It should emit an event that will let the user know that the deposit is successful.
     * It is mandatory to call ERC721 contract back to check if a token is received by auction (require ownerOf(nftId) to be equal address(this))
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    using ERC165Checker for address;
    bytes4 public constant IID_ITEST = type(ITest).interfaceId;
    bytes4 public constant IID_IERC165 = type(IERC165).interfaceId;
    bytes4 public constant IID_IERC1155 = type(IERC1155).interfaceId;
    bytes4 public constant IID_IERC721 = type(IERC721).interfaceId;

    function isERC1155(address nftAddress) external view returns (bool) {
        return nftAddress.supportsInterface(IID_IERC1155);
    }

    function isERC721(address nftAddress) external view returns (bool) {
        return nftAddress.supportsInterface(IID_IERC721);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return interfaceId == IID_ITEST || interfaceId == IID_IERC165;
    }

    /**
     *  list on auction NFT that msg.sender has deposited with safeTransferFrom.
     *  Users willing to list their NFT are free to choose any ERC20 token for bids.
     *  Also, they have to input the auction start UTC timestamp, auction end UTC timestamp and minimum bid amount.
     *  During the auction there should be no way for NFT to leave the contract - it should be locked on contract.
     *  One NFT can participate in only one auction.
     */
    function listToken(uint256 _tokenId, uint256 minBid) external {}
}
