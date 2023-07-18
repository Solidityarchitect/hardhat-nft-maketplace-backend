// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Error
error NftMarketplace__PriceMustBeAboveZero();
error NftMarketplace__NotApprovedForMarketplace();
error NftMarketplace__AlreadyListed(address nftAddress,uint256 tokenId);
error NftMarketplace__NotOwner();
error NftMarketplace__NotListed(address nftAddress,uint256 tokenId);
error NftMarketplace__PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error NftMarketplace__NotProceeds();
error NftMarketplace__TransferFailed();

contract NftMarketplace is ReentrancyGuard{

    // Struct
    struct Listing{
        uint256 price;
        address seller;
    }
    // Events
    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemCanceled(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );

    // NFT Contract address -> NFT TokenID -> Listing struct
    mapping(address => mapping(uint256 => Listing)) private s_listings;

    // Seller address -> Amount earned
    mapping(address => uint256) private s_proceeds;

    // Modifiers
modifier notListed(
        address nftAddress,
        uint256 tokenId
    ) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price > 0) {
            revert NftMarketplace__AlreadyListed(nftAddress, tokenId);
        }
        _;
    }

    modifier isOwner(address nftAddress, uint256 tokenId, address spender){
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if(spender != owner){
            revert NftMarketplace__NotOwner();
        }
        _;
    }

    modifier isListed(address nftAddress, uint256 tokenId){
        Listing memory listing = s_listings[nftAddress][tokenId];
        if(listing.price <= 0){
            revert NftMarketplace__NotListed(nftAddress,tokenId);
        }
        _;
    }

    // Main Function
    function listItem(
        address nftAddress,
        uint256 tokenId,
        uint256 price
    )
        external
        notListed(nftAddress, tokenId)
        isOwner(nftAddress, tokenId, msg.sender)
    {
        if (price <= 0) {
            revert NftMarketplace__PriceMustBeAboveZero();
        }
        IERC721 nft = IERC721(nftAddress);
        if (nft.getApproved(tokenId) != address(this)) {
            revert NftMarketplace__NotApprovedForMarketplace();
        }
        s_listings[nftAddress][tokenId] = Listing(price, msg.sender);
        emit ItemListed(msg.sender, nftAddress, tokenId, price);
    }
        // 1. Send the NFT to the contract. Transfer -> Contract "hold" the NFT.
        // 2. Owners can still hold their NFT, and give the marketplace approval
        // to sell the NFT for them. ✅

    function buyItem(address nftAddress,uint256 tokenId)
    external payable
    isListed(nftAddress, tokenId)
    nonReentrant
    {
        Listing memory listedItem = s_listings[nftAddress][tokenId];
        if(msg.value < listedItem.price){
            revert NftMarketplace__PriceNotMet(nftAddress, tokenId, listedItem.price);
        }

        // Sending the money to the user ❌
        // Have them withdraw the money ✅
        s_proceeds[listedItem.seller] = s_proceeds[listedItem.seller] + msg.value;
        delete (s_listings[nftAddress][tokenId]);
        IERC721(nftAddress).safeTransferFrom(listedItem.seller, msg.sender, tokenId); 
        emit ItemBought(msg.sender, nftAddress, tokenId, listedItem.price);
    }

    function cancelListing(address nftAddress, uint256 tokenId)
     external
     isOwner(nftAddress, tokenId, msg.sender)
     isListed(nftAddress, tokenId)
     {
        delete (s_listings[nftAddress][tokenId]);
        emit ItemCanceled(msg.sender, nftAddress, tokenId);
     }

     function updateListing(address nftAddress, uint256 tokenId, uint256 newPrice)
     external 
     isListed(nftAddress,tokenId)
     isOwner(nftAddress, tokenId, msg.sender)
     {
        if( newPrice <= 0){
            revert NftMarketplace__PriceMustBeAboveZero();
        }
        s_listings[nftAddress][tokenId].price = newPrice;
        emit ItemListed(msg.sender, nftAddress, tokenId, newPrice);
     }

     function withdrawProceeds() external {
        uint256 proceeds = s_proceeds[msg.sender];
        if(proceeds <= 0){
            revert NftMarketplace__NotProceeds();
        }
        s_proceeds[msg.sender] = 0;
        (bool success,) = payable(msg.sender).call{value: proceeds}("");
        if(!success){
            revert NftMarketplace__TransferFailed();
        }
     }

     // Getter Function
     function getListing(address nftAddress, uint256 tokenId)
        external
        view
        returns (Listing memory)
        {
            return s_listings[nftAddress][tokenId];
        }

    function getProceeds(address seller)
    external
    view
    returns (uint256)
    {
        return s_proceeds[seller];
    }
}

    // 1. `listItem`: List NFTs on the marketplace ✅
    // 2. `buyItem`: Buy the NFTs ✅
    // 3. `cancelItem`: Cancel a listing ✅
    // 4. `updateListing`: Update Price ✅
    // 5. `withdrawProceeds`: Withdraw payment for my bought NFTs ✅