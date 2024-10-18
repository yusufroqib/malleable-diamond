// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../contracts/interfaces/IDiamondCut.sol";
import "../../contracts/facets/DiamondCutFacet.sol";
import "../../contracts/facets/DiamondLoupeFacet.sol";
import "../../contracts/facets/OwnershipFacet.sol";
import "../../contracts/facets/PresaleFacet.sol";
import "../../../contracts/facets/ERC721Facet.sol";
import "../../contracts/Diamond.sol";

import "./DiamondUtils.sol";

contract DiamondDeployer is DiamondUtils, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ERC721Facet erc721Facet;
    PresaleFacet presaleFacet;
    ERC721Facet ERC721_Diamond;
    PresaleFacet Presale_Diamond;

    address creator1;
    address creator2;
    address spender;

    uint256 privateKey1;
    uint256 privateKey2;
    uint256 privateKey3;
    string name = "Roccomania";
    string symbol = "RCO";
    address NftAddress2;
    address user1 = vm.addr(0x1);
    address user2 = vm.addr(0x2);
    bytes32 merkleroot =
        0x2ed712f81db5ceb291ebb6cfb4152d38f7a128d1a49ed6219103d9e6c1aca4a3;

    function setUp() public {
        // Deploy facets first
        dCutFacet = new DiamondCutFacet();
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        presaleFacet = new PresaleFacet();
        erc721Facet = new ERC721Facet();

        // Deploy diamond with initial facets
        diamond = new Diamond(
            address(this),
            address(dCutFacet),
            name,
            symbol,
            merkleroot,
            NftAddress2
        );

        // Create function selectors
        FacetCut[] memory cut = new FacetCut[](4);

        // Add DiamondLoupeFacet
        cut[0] = FacetCut({
            facetAddress: address(dLoupe),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("DiamondLoupeFacet")
        });

        // Add OwnershipFacet
        cut[1] = FacetCut({
            facetAddress: address(ownerF),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("OwnershipFacet")
        });

        // Add ERC721Facet
        cut[2] = FacetCut({
            facetAddress: address(erc721Facet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("ERC721Facet")
        });

        // Add PresaleFacet
        cut[3] = FacetCut({
            facetAddress: address(presaleFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("PresaleFacet")
        });

        // Perform the diamond cut
        IDiamondCut(address(diamond)).diamondCut(cut, address(0), "");

        // Initialize facet references AFTER the diamond cut
        ERC721_Diamond = ERC721Facet(address(diamond));
        Presale_Diamond = PresaleFacet(address(diamond));

        // Setup test addresses
        (creator1, privateKey1) = mkaddr("CREATOR");
        (creator2, privateKey2) = mkaddr("CREATOR2");
        (spender, privateKey3) = mkaddr("SPENDER");
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external virtual override {}

    function mkaddr(
        string memory s_name
    ) public returns (address addr, uint256 privateKey) {
        privateKey = uint256(keccak256(abi.encodePacked(s_name)));
        addr = vm.addr(privateKey);
        vm.label(addr, s_name);
    }

    function switchSigner(address _newSigner) public {
        vm.startPrank(_newSigner);
        vm.deal(_newSigner, 3 ether);
        vm.label(_newSigner, "USER");
    }
}
