//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Auction {
    struct Listing {
        IERC721 nft;
        uint nftId;
        uint minPrice;
        uint highestBid;
        address highestBidder;
        uint endTime;
        address owner;
    }

    uint nexListingId;
    mapping(uint => Listing) listings;
    mapping(address => uint) balances;

    event List(
        address indexed lister,
        address indexed nft,
        uint256 indexed nftId,
        uint256 listingId,
        uint256 minPrice,
        uint256 endTime,
        uint256 timestamp
    );
    event Bid(
        address indexed bidder,
        uint256 indexed listingId,
        uint256 amount,
        uint256 timestamp
    );

    modifier listingExists(uint listingId) {
        require(
            listings[listingId].owner != address(0),
            "Listing does not exist"
        );
        _;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function list(address nft, uint nftId, uint minPrice, uint numHours) external {
        IERC721 nftContract = IERC721(nft);
        require(nftContract.ownerOf(nftId) == msg.sender, "You do not own this NFT");
        require(
            nftContract.getApproved(nftId) == address(this),
            "This contract is not approved to access this NFT"
        );

        nftContract.safeTransferFrom(msg.sender, address(this), nftId);

        Listing storage listing = listings[nexListingId];
        listing.nft = nftContract;
        listing.nftId = nftId;
        listing.minPrice = minPrice;
        listing.endTime = block.timestamp + (numHours * 1 hours);
        listing.owner = msg.sender;
        listing.highestBidder = msg.sender;

        emit List(
            msg.sender,
            nft,
            nftId,
            nexListingId,
            minPrice,
            listing.endTime,
            block.timestamp
        );

        nexListingId++;
    }

    function bid(uint listingId) external payable listingExists((listingId)) {
        Listing storage listing = listings[listingId];
        require(
            msg.value >= listing.minPrice,
            "You must bid at least the min price"
        );
        require(
            msg.value > listing.highestBid,
            "You must bid higher than the highest bid"
        );
        require(block.timestamp < listing.endTime, "Auction is over");

        balances[listing.highestBidder] += listing.highestBid;
        listing.highestBid = msg.value;
        listing.highestBidder = msg.sender;

        emit Bid(msg.sender, listingId, msg.value, block.timestamp);
    }

    function end(uint256 listingId) external listingExists(listingId) {
        Listing storage listing = listings[listingId];
        require(block.timestamp > listing.endTime, "Auction is not over");

        balances[listing.owner] += listing.highestBid;
        listing.nft.safeTransferFrom(
            address(this),
            listing.highestBidder,
            listing.nftId
        );
        delete listings[listingId];
    }

    function withdrawFunds() external {
        uint balance = balances[msg.sender];
        balances[msg.sender] = 0;

        (bool sent, ) = payable(msg.sender).call{value: balance}("");
        require(sent, "Transaction failed");
    }

    function getListing(
        uint listingId
    )
        public
        view
        listingExists(listingId)
        returns (address, uint256, uint256, uint256, uint256)
    {
        return (
            address(listings[listingId].nft),
            listings[listingId].nftId,
            listings[listingId].highestBid,
            listings[listingId].minPrice,
            listings[listingId].endTime
        );
    }
}
