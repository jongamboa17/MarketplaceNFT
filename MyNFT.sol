// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MyNFT is ERC721 {
    uint256 token_count;

    constructor() ERC721("MyNFT17", "MNFT17") {}

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "ERC721Metadata: URI query for nonexistent token");
        return "https://ipfs.io/ipfs/QmT9ZdgifsoWVZKyCr3o5qEuQv3wrHDR6265vAZeh6Q3LS";
    }

    function mintNFT(address to) public
    {
        token_count  += 1;
        _mint(to, token_count);
    }
}