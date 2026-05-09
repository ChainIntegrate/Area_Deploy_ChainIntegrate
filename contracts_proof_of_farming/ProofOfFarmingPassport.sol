// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
    Proof of Farming - FarmPassport V1

    1 token LSP8 = 1 azienda agricola.
*/

import {
    LSP8Mintable
} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/presets/LSP8Mintable.sol";

import {
    _LSP4_TOKEN_TYPE_COLLECTION
} from "@lukso/lsp-smart-contracts/contracts/LSP4DigitalAssetMetadata/LSP4Constants.sol";

import {
    _LSP8_TOKENID_FORMAT_NUMBER
} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8Constants.sol";

contract ProofOfFarmingPassport is LSP8Mintable {

    enum FarmStatus {
        None,
        Active,
        Suspended,
        Revoked
    }

    struct Farm {
        bytes32 farmId;
        string publicName;
        string metadataURI;
        FarmStatus status;
        uint256 createdAt;
        uint256 updatedAt;
    }

    mapping(bytes32 => Farm) private farms;
    mapping(bytes32 => bool) public farmExists;

    event FarmCreated(
        bytes32 indexed farmId,
        address indexed recipient,
        string publicName,
        string metadataURI
    );

    event FarmStatusUpdated(
        bytes32 indexed farmId,
        FarmStatus status
    );

    event FarmMetadataUpdated(
        bytes32 indexed farmId,
        string metadataURI
    );

    constructor(
        address contractOwner
    )
        LSP8Mintable(
            "Proof of Farming Passport",
            "POFARM",
            contractOwner,
            _LSP4_TOKEN_TYPE_COLLECTION,
            _LSP8_TOKENID_FORMAT_NUMBER
        )
    {}

    function createFarmPassport(
        address recipient,
        bytes32 farmId,
        string calldata publicName,
        string calldata metadataURI
    ) external onlyOwner {

        require(recipient != address(0), "Invalid recipient");
        require(farmId != bytes32(0), "Invalid farmId");
        require(!farmExists[farmId], "Farm already exists");

        farmExists[farmId] = true;

        farms[farmId] = Farm({
            farmId: farmId,
            publicName: publicName,
            metadataURI: metadataURI,
            status: FarmStatus.Active,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        _mint(recipient, farmId, true, "");

        emit FarmCreated(
            farmId,
            recipient,
            publicName,
            metadataURI
        );
    }

    function updateFarmMetadata(
        bytes32 farmId,
        string calldata metadataURI
    ) external onlyOwner {

        require(farmExists[farmId], "Farm does not exist");

        farms[farmId].metadataURI = metadataURI;
        farms[farmId].updatedAt = block.timestamp;

        emit FarmMetadataUpdated(
            farmId,
            metadataURI
        );
    }

    function updateFarmStatus(
        bytes32 farmId,
        FarmStatus status
    ) external onlyOwner {

        require(farmExists[farmId], "Farm does not exist");

        farms[farmId].status = status;
        farms[farmId].updatedAt = block.timestamp;

        emit FarmStatusUpdated(
            farmId,
            status
        );
    }

    function getFarm(
        bytes32 farmId
    ) external view returns (Farm memory) {

        require(farmExists[farmId], "Farm does not exist");

        return farms[farmId];
    }

    /*
        Soulbound logic:
        blocca i trasferimenti tra utenti.
    */
    function _beforeTokenTransfer(
        address from,
        address to,
        bytes32 tokenId,
        bool force,
        bytes memory data
    ) internal virtual override {

        require(
            from == address(0) || to == address(0),
            "ProofOfFarming: passport is soulbound"
        );

        super._beforeTokenTransfer(
            from,
            to,
            tokenId,
            force,
            data
        );
    }
}
