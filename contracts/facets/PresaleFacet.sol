// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {MerkleProof} from "../libraries/MerkleProof.sol";
import "./ERC721Facet.sol";

contract PresaleFacet {
    error InvalidProof();
    error AlreadyMinted();
    error IncorrectEthSent();

    event MintedNft(
        address indexed nftContract,
        address indexed to,
        uint256 indexed tokenId
    );

    uint256 public constant NFT_PRICE = 0.01 ether;
    // Number of NFTs per 1 ETH
    uint256 public constant NFTS_PER_ETHER = 30;

    function diaStorage()
        internal
        pure
        returns (LibDiamond.DiamondStorage storage)
    {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds;
    }

    function mintPresale(bytes32[] calldata proof) external payable {
        // Check if already Minted
        if (diaStorage().hasMinted[msg.sender]) {
            revert AlreadyMinted();
        }
        // Check if minimum ETH is sent
        if (msg.value < NFT_PRICE) {
            revert IncorrectEthSent();
        }

        // Verify the proof
        if (!_verifyProof(proof, msg.sender)) {
            revert InvalidProof();
        }

      


        // Calculate the number of NFTs to mint based on the ETH sent
        uint256 numNfts = (msg.value * NFTS_PER_ETHER) / 1 ether;

        address nftAddr = diaStorage().token;

        // Set status to Minted
        diaStorage().hasMinted[msg.sender] = true;

        // Mint the NFTs
        for (uint256 i = 0; i < numNfts; i++) {
            diaStorage().tokenIds++;
            ERC721Facet(nftAddr).mint(msg.sender, diaStorage().tokenIds + i);
            emit MintedNft(
                address(this),
                msg.sender,
                diaStorage().tokenIds + i
            );
        }
    }

    function updateMerkleRoot(bytes32 _newMerkleroot) external {
        LibDiamond.enforceIsContractOwner();
        diaStorage().merkleRoot = _newMerkleroot;
    }

    function _verifyProof(
        bytes32[] memory proof,
        address addr
    ) private view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(addr));
        // console.logBytes32(leaf);

        return MerkleProof.verify(proof, diaStorage().merkleRoot, leaf);
    }
}
