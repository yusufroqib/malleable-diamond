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
import "forge-std/console.sol"; // For logging
import "../contracts/facets/ERC721Facet.sol";

contract PresaleFacetTest is DiamondDeployer {
    struct WhitelistData {
        bytes32 merkleRoot;
        mapping(address => bytes32[]) proofs;
        address[] addresses;
    }

    WhitelistData internal whitelistData;
    string internal json;

    // address NftAddress = address(ERC721_Diamond);

    function setUp() public virtual override {
        super.setUp(); // Call parent setUp first

        // Load and parse the JSON file
        json = vm.readFile("test/airdrop_proofs.json");
        whitelistData.merkleRoot = abi.decode(
            vm.parseJson(json, ".merkleRoot"),
            (bytes32)
        );

        // Update the merkle root in the contract
        Presale_Diamond.updateMerkleRoot(whitelistData.merkleRoot);

        // Read addresses array
        bytes memory addressesData = vm.parseJson(json, ".addresses");
        address[] memory addresses = abi.decode(addressesData, (address[]));
        whitelistData.addresses = addresses;

        // Process each address
        for (uint i = 0; i < addresses.length; i++) {
            address addr = addresses[i];

            // Read proof array for this address
            string memory proofPath = string.concat(
                ".proofs.",
                vm.toString(addr)
            );
            bytes memory proofData = vm.parseJson(json, proofPath);
            bytes32[] memory proof = abi.decode(proofData, (bytes32[]));
            whitelistData.proofs[addr] = proof;

            // Fund the address for testing
            vm.deal(addr, 2 ether);
        }
    }

    function testPresale_MinimumPurchase() public {
        address testAddr = whitelistData.addresses[0];
        bytes32[] memory proof = whitelistData.proofs[testAddr];

        vm.startPrank(testAddr);
        Presale_Diamond.mintPresale{value: 1 ether}(proof);
        assertEq(erc721Facet.balanceOf(testAddr), 30);
        vm.stopPrank();
    }

    function testFailPresale_InvalidProof() public {
        // Use non-whitelisted address
        vm.startPrank(user1);

        // Try to use proof from first whitelisted address
        bytes32[] memory proof = whitelistData.proofs[
            whitelistData.addresses[0]
        ];

        // vm.expectRevert(PresaleFacet.InvalidProof.selector);
        Presale_Diamond.mintPresale{value: 1 ether}(proof);

        vm.stopPrank();
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
