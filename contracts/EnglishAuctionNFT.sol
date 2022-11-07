// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./TokenERC721.sol";

import "hardhat/console.sol";

interface ITest {
    function isERC1155(address nftAddress) external returns (bool);

    function isERC721(address nftAddress) external returns (bool);
}

contract EnglishAuction is Ownable, ReentrancyGuard {
    struct Asset {
        uint256 ID;
        uint256 minBid;
        address tokenPayable;
        address seller;
        uint256 startAt;
        uint256 endAt;
        bool listed;
        address highestBidder;
        uint256 highestBid;
        uint256 bidsCount;
        address NFT;
        address buyer;
    }

    // ****************** EVENTS ******************
    event AssetListed(
        address indexed seller,
        uint256 indexed ID,
        uint256 minBid,
        address token
    );
    event AssetDeListed(uint256 indexed ID);
    event Bid(
        address indexed bidder,
        uint256 indexed ID,
        uint256 bid,
        address token
    );
    event BidReturn(
        address indexed bidder,
        uint256 indexed ID,
        uint256 amount,
        address token
    );
    event Withdraw(uint256 indexed ID, address indexed seller);
    event Sale(
        uint256 indexed ID,
        address buyer,
        uint256 amount,
        address token
    );

    event TransferReceivedToken(address _from, uint256 _amount, address token);
    event TransferSentToken(address _destAddr, uint256 _amount, address token);

    event TransferReceivedNFT(address _from, uint256 ID);
    event TransferSentNFT(address _destAddr, uint256 ID);

    // ****************** VARS ******************

    using Counters for Counters.Counter;
    Counters.Counter private _assetsIDs;
    Counters.Counter private _assetsSold;
    address contractsOwner;
    // uint256 adminFee = 0.01 ether;
    TokenERC721 public nft;
    IERC20 public token;

    mapping(uint256 => Asset) private _auctionAssets;

    constructor() {
        contractsOwner = msg.sender;
    }

    // ****************** RECEIVER ******************

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

    // // ****************** VERIFY CONTRACT's TYPE ******************

    using ERC165Checker for address;
    bytes4 public constant IID_ITEST = type(ITest).interfaceId;
    bytes4 public constant IID_IERC165 = type(IERC165).interfaceId;
    bytes4 public constant IID_IERC1155 = type(IERC1155).interfaceId;
    bytes4 public constant IID_IERC721 = type(IERC721).interfaceId;

    function isERC1155(address nftAddress) private view returns (bool) {
        return nftAddress.supportsInterface(IID_IERC1155);
    }

    function isERC721(address nftAddress) private view returns (bool) {
        return nftAddress.supportsInterface(IID_IERC721);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        returns (bool)
    {
        return interfaceId == IID_ITEST || interfaceId == IID_IERC165;
    }

    // ****************** PUBLIC FUNCTIONS ******************

    /**
     *  list on auction NFT that msg.sender has deposited with safeTransferFrom.
     *  Users willing to list their NFT are free to choose any ERC20 token for bids.
     *  Also, they have to input the auction start UTC timestamp, auction end UTC timestamp and minimum bid amount.
     *  During the auction there should be no way for NFT to leave the contract - it should be locked on contract.
     *  One NFT can participate in only one auction.
     */
    function listAsset(
        uint256 _assetID,
        address _tokenContractERC20,
        address _nftAddress,
        uint256 _minBid,
        uint256 _startAt,
        uint256 _endAt
    ) external nonReentrant {
        require(_startAt > block.timestamp, "future start only");
        require(_endAt > _startAt, "ends after starts only");
        require(isERC721(_nftAddress), "not an ERC721");
        // require(!isERC1155(_nftAddress), "not an ERC1155");

        nft = TokenERC721(_nftAddress);
        require(nft.ownerOf(_assetID) == msg.sender, "only owner");

        nft.safeTransferFrom(msg.sender, address(this), _assetID);

        _auctionAssets[_assetID].ID = _assetID;
        _auctionAssets[_assetID].minBid = _minBid;
        _auctionAssets[_assetID].tokenPayable = _tokenContractERC20;
        _auctionAssets[_assetID].seller = msg.sender;
        _auctionAssets[_assetID].startAt = _startAt;
        _auctionAssets[_assetID].endAt = _endAt;
        _auctionAssets[_assetID].listed = true;
        _auctionAssets[_assetID].NFT = _nftAddress;

        emit TransferReceivedNFT(msg.sender, _assetID);
        emit AssetListed(msg.sender, _assetID, _minBid, _tokenContractERC20);
    }

    /**
     * should take from user ERC20 tokens specified in listOnAuction function for specific NFT (address+tokenId).
     * Function should revert if bid is placed out of auction effective time range specified in listNFTOnAuction.
     * Bid cannot be reverted, once tokens are deposited, they can be only returned when bidder loses.
     */
    function placeBid(uint256 _assetID, uint256 _bid) public nonReentrant {
        require(_auctionAssets[_assetID].listed == true, "asset not listed");
        require(
            _auctionAssets[_assetID].startAt <= block.timestamp,
            "auction yet to start"
        );
        require(
            _auctionAssets[_assetID].endAt >= block.timestamp,
            "auction ended"
        );
        require(
            _auctionAssets[_assetID].highestBid < _bid,
            "last bid is higher"
        );
        require(_auctionAssets[_assetID].minBid < _bid, "min bid is higher");

        token = IERC20(_auctionAssets[_assetID].tokenPayable);

        if (_auctionAssets[_assetID].highestBidder != address(0)) {
            token.transfer(
                payable(_auctionAssets[_assetID].highestBidder),
                _auctionAssets[_assetID].highestBid
            );
            emit TransferSentToken(
                _auctionAssets[_assetID].highestBidder,
                _auctionAssets[_assetID].highestBid,
                _auctionAssets[_assetID].tokenPayable
            );
            emit BidReturn(
                _auctionAssets[_assetID].highestBidder,
                _assetID,
                _auctionAssets[_assetID].highestBid,
                _auctionAssets[_assetID].tokenPayable
            );
        }

        token.transferFrom(msg.sender, address(this), _bid);
        emit TransferReceivedToken(
            msg.sender,
            _bid,
            _auctionAssets[_assetID].tokenPayable
        );

        _auctionAssets[_assetID].highestBid = _bid;
        _auctionAssets[_assetID].highestBidder = msg.sender;
        _auctionAssets[_assetID].bidsCount++;

        emit Bid(
            msg.sender,
            _assetID,
            _bid,
            _auctionAssets[_assetID].tokenPayable
        );
    }

    /**
     * can be called by anyone on blockchain after auction end UTC timestamp is reached.
     * Function should summarize auction results, transfer winning amount of ERC20 tokens to the auction issuer and unlock NFT for withdrawal
     * or placing on auction again only for the auction winner.
     * Note, that if the auction is finished without any single bid,
     * it should not make any ERC20 token transfer and let the auction issuer withdraw the token or start auction again.
     */
    function finishAuction(uint256 _assetID) public nonReentrant {
        require(
            _auctionAssets[_assetID].endAt < block.timestamp,
            "auction in progress"
        );

        require(_auctionAssets[_assetID].listed, "non listed asset");

        token = IERC20(_auctionAssets[_assetID].tokenPayable);

        if (
            _auctionAssets[_assetID].highestBid >
            _auctionAssets[_assetID].minBid
        ) {
            nft.safeTransferFrom(
                address(this),
                _auctionAssets[_assetID].highestBidder,
                _assetID
            );
            emit TransferSentNFT(
                _auctionAssets[_assetID].highestBidder,
                _assetID
            );

            token.transfer(
                _auctionAssets[_assetID].seller,
                _auctionAssets[_assetID].highestBid
            );
            emit TransferSentToken(
                _auctionAssets[_assetID].seller,
                _auctionAssets[_assetID].highestBid,
                _auctionAssets[_assetID].tokenPayable
            );

            _auctionAssets[_assetID].buyer = _auctionAssets[_assetID]
                .highestBidder;
            _auctionAssets[_assetID].listed = false;
            emit Sale(
                _assetID,
                _auctionAssets[_assetID].highestBidder,
                _auctionAssets[_assetID].highestBid,
                _auctionAssets[_assetID].tokenPayable
            );
        } else {
            withdrawNft(_assetID);
            emit Withdraw(_assetID, _auctionAssets[_assetID].seller);
        }
    }

    /**
     *  transfers NFT to its owner. Owner of NFT is an address who has deposited an NFT and never placed it on auction,
     *  or deposited an NFT and placed on auction that didn’t receive any at least minimum bid,
     *   or auction winner that didn’t place his earned NFT on auction. During the auction NFT can’t be withdrawn.
     */
    function withdrawNft(uint256 _assetID) private {
        nft = TokenERC721(_auctionAssets[_assetID].NFT);

        nft.safeTransferFrom(
            address(this),
            _auctionAssets[_assetID].seller,
            _assetID
        );
        emit TransferSentNFT(_auctionAssets[_assetID].seller, _assetID);

        _auctionAssets[_assetID].buyer = _auctionAssets[_assetID].seller;
        _auctionAssets[_assetID].listed = false;
    }
}
