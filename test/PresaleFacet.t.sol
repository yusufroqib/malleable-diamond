// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/Diamond.sol";
import "./helpers/DiamondUtils.sol";
import "./helpers/DiamondDeployer.sol";
import "forge-std/Test.sol";
import "forge-std/StdJson.sol";

contract PresaleFacetTest is DiamondDeployer {
    using stdJson for string;
    
    struct WhitelistData {
        bytes32 merkleRoot;
        mapping(address => bytes32[]) proofs;
        address[] addresses;
    }
    
    WhitelistData internal whitelistData;
    string internal json;

    function setUp() public virtual override {
        // First load and parse the JSON file
        json = vm.readFile("airdrop_proofs.json");
        whitelistData.merkleRoot = bytes32(json.readBytes32(".merkleRoot"));
        
        // Read all addresses from the proofs object
        string[] memory addressStrings = json.readStringArray(".addresses");
        whitelistData.addresses = new address[](addressStrings.length);
        
        // For each address, read its proof
        for(uint i = 0; i < addressStrings.length; i++) {
            address addr = vm.parseAddress(addressStrings[i]);
            whitelistData.addresses[i] = addr;
            
            // Read proof array for this address
            string memory proofPath = string.concat(".proofs.", addressStrings[i]);
            bytes32[] memory proof = json.readBytes32Array(proofPath);
            
            // Store proof in mapping
            whitelistData.proofs[addr] = proof;
            
            // Fund the address for testing
            vm.deal(addr, 2 ether);
        }

        // Now call the parent setUp with our loaded merkleRoot
        super.setUp();
    }

    function testPresale_MinimumPurchase() public {
        address testAddr = whitelistData.addresses[0];
        bytes32[] memory proof = whitelistData.proofs[testAddr];
        
        vm.startPrank(testAddr);
        Presale_Diamond.mintPresale{value: 0.01 ether}(proof);
        
        // 0.01 ETH should mint 0.3 NFTs, rounded down to 0 NFTs
        assertEq(ERC721_Diamond.balanceOf(testAddr), 1);
        vm.stopPrank();
    }

    function testPresale_FullEtherPurchase() public {
        address testAddr = whitelistData.addresses[0];
        bytes32[] memory proof = whitelistData.proofs[testAddr];
        
        vm.startPrank(testAddr);
        Presale_Diamond.mintPresale{value: 1 ether}(proof);
        
        // 1 ETH should mint 30 NFTs
        assertEq(ERC721_Diamond.balanceOf(testAddr), 30);
        vm.stopPrank();
    }

    function testPresale_InvalidProof() public {
        // Use non-whitelisted address
        vm.startPrank(user1);
        
        // Try to use proof from first whitelisted address
        bytes32[] memory proof = whitelistData.proofs[whitelistData.addresses[0]];
        
        vm.expectRevert(PresaleFacet.InvalidProof.selector);
        Presale_Diamond.mintPresale{value: 1 ether}(proof);
        
        vm.stopPrank();
    }

    function testPresale_InsufficientPayment() public {
        address testAddr = whitelistData.addresses[0];
        bytes32[] memory proof = whitelistData.proofs[testAddr];
        
        vm.startPrank(testAddr);
        
        vm.expectRevert(PresaleFacet.IncorrectEthSent.selector);
        Presale_Diamond.mintPresale{value: 0.009 ether}(proof);
        
        vm.stopPrank();
    }

    function testPresale_MultipleMints() public {
        address testAddr = whitelistData.addresses[0];
        bytes32[] memory proof = whitelistData.proofs[testAddr];
        
        vm.startPrank(testAddr);
        
        // First mint should succeed
        Presale_Diamond.mintPresale{value: 1 ether}(proof);
        
        // Second mint should fail
        vm.expectRevert(PresaleFacet.AlreadyMinted.selector);
        Presale_Diamond.mintPresale{value: 1 ether}(proof);
        
        vm.stopPrank();
    }

    function testPresale_DifferentUsers() public {
        address user1 = whitelistData.addresses[0];
        address user2 = whitelistData.addresses[1];
        
        // First user mints
        vm.prank(user1);
        Presale_Diamond.mintPresale{value: 1 ether}(whitelistData.proofs[user1]);
        assertEq(ERC721_Diamond.balanceOf(user1), 30);

        // Second user mints
        vm.prank(user2);
        Presale_Diamond.mintPresale{value: 0.5 ether}(whitelistData.proofs[user2]);
        assertEq(ERC721_Diamond.balanceOf(user2), 15);
    }

    function testPresale_UpdateMerkleRoot() public {
        bytes32 newRoot = bytes32(uint256(1));
        address testAddr = whitelistData.addresses[0];
        bytes32[] memory proof = whitelistData.proofs[testAddr];
        
        // Only owner should be able to update merkle root
        vm.prank(address(this));
        Presale_Diamond.updateMerkleRoot(newRoot);
        
        // Previous proofs should no longer work
        vm.startPrank(testAddr);
        vm.expectRevert(PresaleFacet.InvalidProof.selector);
        Presale_Diamond.mintPresale{value: 1 ether}(proof);
        vm.stopPrank();
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}