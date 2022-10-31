// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EnglishAuction is
    IERC721Receiver,
    ERC721URIStorage,
    Ownable,
    ReentrancyGuard
{
    struct ListedToken {
        uint256 ID;
        IERC721 nft;
        address payable seller;
        address payable owner;
        uint256 endAt;
        uint256 startAt;
        address highestBidder;
        uint highestBid;
        mapping(address => uint256) bids;
        uint256 bidsCount;
        uint256 price;
        address ERC20;
        bool listed;
    }

    // ****************** EVENTS ******************
    event Start();
    event Bid(address indexed sender, uint amount);
    event Withdraw(address indexed bidder, uint amount);
    event End(address winner, uint amount);

    // ****************** VARS ******************

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;
    address payable contractsowner;
    uint256 adminFee = 0.01 ether;

    mapping(uint256 => ListedToken) private idToListedToken;

    constructor() ERC721("EnglishAuction", "EAU") {
        contractsowner = payable(msg.sender);
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
}
