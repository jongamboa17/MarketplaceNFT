// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MarketplaceNFT is ReentrancyGuard {

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool sold;
    }

    address private owner;
    bool private paused;
    Listing[] public listings;
    mapping(address => mapping(uint256 => bool)) public activeListings;

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }
    modifier whenNotPaused() {
        require(!paused, "The contract is paused");
        _;
    }

    modifier onlySeller(uint256 listingId) {
        require(listings[listingId].seller == msg.sender, "You are not the seller");
        _;
    }

    event Paused();
    event Unpaused();
    event NFTListed(address indexed seller, address indexed nftContract, uint256 indexed tokenId, uint256 price);
    event NFTSold(address indexed buyer, address indexed nftContract, uint256 indexed tokenId, uint256 price);
    event ListingCanceled(address indexed seller, address indexed nftContract, uint256 indexed tokenId);
    event ListingPriceUpdated(address indexed seller, address indexed nftContract, uint256 indexed tokenId, uint256 newPrice);

    constructor() {
        owner = msg.sender;
        paused = false;
    }

    function pause() public onlyOwner {
        paused = true;
        emit Paused();
    }

    function unpause() public onlyOwner {
        paused = false;
        emit Unpaused();
    }

    function isActiveListing(address nftContract, uint256 tokenId) external view returns (bool) {
        return activeListings[nftContract][tokenId];
    }

    function listNFT(address nftContract, uint256 tokenId, uint256 price) external whenNotPaused {
        require(price > 0, "Price must be greater than 0");
        require(IERC721(nftContract).supportsInterface(0x80ac58cd), "Contract is not ERC721");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "You are not the owner");

        // Ensure the marketplace is approved to transfer the NFT
        require(
            IERC721(nftContract).getApproved(tokenId) == address(this) || 
            IERC721(nftContract).isApprovedForAll(msg.sender, address(this)), 
            "Marketplace is not approved to transfer this NFT"
        );

        // Record the listing without transferring the NFT
        listings.push(Listing(msg.sender, nftContract, tokenId, price, false));
        activeListings[nftContract][tokenId] = true;

        emit NFTListed(msg.sender, nftContract, tokenId, price);
    }

    function buyNFT(uint256 listingId) external payable whenNotPaused nonReentrant {
        Listing storage listing = listings[listingId];
        require(msg.value == listing.price, "Incorrect price");
        require(!listing.sold, "NFT already sold");

        // Ensure that the marketplace is still approved to transfer the NFT on behalf of the seller
        require(
            IERC721(listing.nftContract).getApproved(listing.tokenId) == address(this) || 
            IERC721(listing.nftContract).isApprovedForAll(listing.seller, address(this)), 
            "Marketplace is not approved to transfer this NFT"
        );

        // Mark the listing as sold before making external calls
        listing.sold = true;
        activeListings[listing.nftContract][listing.tokenId] = false;

        // Transfer the NFT directly from the seller to the buyer
        IERC721(listing.nftContract).safeTransferFrom(listing.seller, msg.sender, listing.tokenId);

        // Transfer the payment to the seller
        (bool success, ) = payable(listing.seller).call{value: msg.value}("");
        require(success, "Transfer to seller failed");

        emit NFTSold(msg.sender, listing.nftContract, listing.tokenId, listing.price);
    }

    function cancelListing(uint256 listingId) external whenNotPaused onlySeller(listingId) {
        Listing storage listing = listings[listingId];
        require(!listing.sold, "NFT already sold");

        activeListings[listing.nftContract][listing.tokenId] = false;
        emit ListingCanceled(listing.seller, listing.nftContract, listing.tokenId);
    }

    function updateListingPrice(uint256 listingId, uint256 newPrice) external whenNotPaused onlySeller(listingId) {
        Listing storage listing = listings[listingId];
        require(!listing.sold, "NFT already sold");
        require(newPrice > 0, "Price must be greater than 0");

        listing.price = newPrice;
        emit ListingPriceUpdated(listing.seller, listing.nftContract, listing.tokenId, newPrice);
    }
}