// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

// LUKSO
import { LSP8IdentifiableDigitalAsset } from "@lukso/lsp8-contracts/contracts/LSP8IdentifiableDigitalAsset.sol";
import { _LSP8_TOKENID_FORMAT_HASH } from "@lukso/lsp8-contracts/contracts/LSP8Constants.sol";
import { _LSP4_TOKEN_TYPE_COLLECTION } from "@lukso/lsp4-contracts/contracts/LSP4Constants.sol";

/**
 * Vehicle Passport Registry
 *
 * Modello:
 * - ChainIntegrate = contract owner / admin
 * - issuer autorizzati = concessionari
 * - tokenId = bytes32 hash del VIN normalizzato off-chain
 * - metadata originari del veicolo salvati come token-scoped data
 * - metadata originari aggiornabili dal writer finche' non frozen
 * - owner del token autorizza operatori a scrivere record
 * - autorizzazioni con authorizationId + vehicleAuthorizationEpoch
 * - operatore crea un record completo a fine lavoro
 * - ownership transfer record automatico al transfer del token
 *
 * Nota:
 * - il contratto non assume che il proprietario sia una Universal Profile
 * - owner/operator/issuer sono semplicemente address
 * - quindi i token possono stare sia su UP sia su wallet normali
 */
contract VehiclePassportRegistry is LSP8IdentifiableDigitalAsset {
    // =========================================================
    // ENUM
    // =========================================================

    enum RecordCategory {
        OrdinaryMaintenance,
        ExtraordinaryMaintenance,
        MechanicalRepair,
        BodyRepair,
        TireService,
        InspectionRevision,
        SoftwareUpdate,
        RecallCampaign,
        OwnershipTransfer
    }

    enum RecordCause {
        None,
        Routine,
        Wear,
        Accident,
        Recall,
        InspectionOutcome,
        Diagnostic,
        Other
    }

    enum PassportStatus {
        Active,
        Suspended,
        Reissued,
        Archived
    }

    enum AuthorizationMode {
        OneShot,
        Reusable
    }

    // =========================================================
    // TOKEN-SCOPED DATA KEYS
    // =========================================================

    bytes32 public constant ORIGIN_METADATA_URI_KEY =
        keccak256("VehiclePassport:OriginMetadataURI");

    bytes32 public constant ORIGIN_METADATA_HASH_KEY =
        keccak256("VehiclePassport:OriginMetadataHash");

    bytes32 public constant ORIGIN_METADATA_FROZEN_KEY =
        keccak256("VehiclePassport:OriginMetadataFrozen");

    // =========================================================
    // STRUCT
    // =========================================================

    struct VehiclePassport {
        bool exists;
        address issuer;
        PassportStatus status;
        uint64 createdAt;
        uint64 lastOwnershipChangeAt;
    }

    struct OriginMetadataControl {
        address writtenBy;
        uint64 updatedAt;
        bool frozen;
    }

    struct WriteAuthorization {
        bool active;
        uint256 authorizationId;
        bytes32 tokenId;
        address grantedBy;
        address operator;
        RecordCategory category;
        AuthorizationMode mode;
        uint64 validFrom;
        uint64 validUntil; // 0 = no expiry
        uint256 epoch;
    }

    struct ServiceRecord {
        bool exists;
        uint256 recordId;
        bytes32 tokenId;
        uint256 authorizationId; // 0 for system records
        RecordCategory category;
        RecordCause cause;
        address writer;
        uint64 createdAt;
        uint64 workStartedAt;
        uint64 workCompletedAt;
        uint32 odometerKm;
        string recordURI;
        bytes32 recordHash;
        bool frozen;
        uint256 supersedesRecordId;
        bool systemGenerated;
    }

    // =========================================================
    // STORAGE
    // =========================================================

    mapping(address => bool) public authorizedIssuers;

    mapping(bytes32 => VehiclePassport) public passports;
    mapping(bytes32 => OriginMetadataControl) public originMetadataControls;

    uint256 public nextAuthorizationId = 1;
    mapping(uint256 => WriteAuthorization) public authorizations;
    mapping(bytes32 => uint256[]) private authorizationIdsByVehicle;

    uint256 public nextRecordId = 1;
    mapping(uint256 => ServiceRecord) public records;
    mapping(bytes32 => uint256[]) private recordIdsByVehicle;

    mapping(bytes32 => uint256) public vehicleAuthorizationEpoch;

    // =========================================================
    // EVENTS
    // =========================================================

    event IssuerAuthorized(address indexed issuer);
    event IssuerRevoked(address indexed issuer);

    event VehiclePassportMinted(
        bytes32 indexed tokenId,
        address indexed issuer,
        address indexed firstOwner
    );

    event OriginMetadataUpdated(
        bytes32 indexed tokenId,
        address indexed writer,
        string metadataURI,
        bytes32 metadataHash
    );

    event OriginMetadataFrozen(
        bytes32 indexed tokenId,
        address indexed writer
    );

    event WriteAuthorizationGranted(
        uint256 indexed authorizationId,
        bytes32 indexed tokenId,
        address indexed grantedBy,
        address operator,
        RecordCategory category,
        AuthorizationMode mode,
        uint256 epoch
    );

    event WriteAuthorizationRevoked(
        uint256 indexed authorizationId,
        bytes32 indexed tokenId,
        address indexed revokedBy
    );

    event ServiceRecordCreated(
        uint256 indexed recordId,
        bytes32 indexed tokenId,
        uint256 indexed authorizationId,
        address writer,
        RecordCategory category,
        RecordCause cause
    );

    event PassportStatusUpdated(
        bytes32 indexed tokenId,
        PassportStatus newStatus
    );

    event VehicleAuthorizationEpochIncremented(
        bytes32 indexed tokenId,
        uint256 newEpoch
    );

    event OwnershipTransferRecordCreated(
        uint256 indexed recordId,
        bytes32 indexed tokenId,
        address indexed from,
        address to
    );

    // =========================================================
    // ERRORS
    // =========================================================

    error NotAuthorizedIssuer();
    error InvalidIssuer();
    error InvalidFirstOwner();
    error InvalidOperator();
    error PassportAlreadyExists();
    error PassportDoesNotExist();
    error NotTokenOwner();
    error InvalidValidityRange();
    error OriginMetadataAlreadyFrozen();
    error OriginMetadataNotWritableByCaller();
    error AuthorizationNotFound();
    error AuthorizationInactive();
    error AuthorizationWrongOperator();
    error AuthorizationWrongEpoch();
    error AuthorizationOwnerMismatch();
    error AuthorizationNotStarted();
    error AuthorizationExpired();
    error OwnershipTransferManualRecordForbidden();
    error InvalidWorkDates();
    error WorkCompletionInFuture();
    error SupersededRecordNotFound();
    error SupersededRecordWrongVehicle();

    // =========================================================
    // CONSTRUCTOR
    // =========================================================

    constructor(address chainIntegrateOwner)
        LSP8IdentifiableDigitalAsset(
            "Vehicle Passport",
            "VPASS",
            chainIntegrateOwner,
            _LSP4_TOKEN_TYPE_COLLECTION,
            _LSP8_TOKENID_FORMAT_HASH
        )
    {}

    // =========================================================
    // MODIFIERS
    // =========================================================

    modifier onlyAuthorizedIssuer() {
        if (!authorizedIssuers[msg.sender]) revert NotAuthorizedIssuer();
        _;
    }

    modifier onlyExistingPassport(bytes32 tokenId) {
        if (!passports[tokenId].exists) revert PassportDoesNotExist();
        _;
    }

    modifier onlyCurrentTokenOwner(bytes32 tokenId) {
        if (tokenOwnerOf(tokenId) != msg.sender) revert NotTokenOwner();
        _;
    }

    // =========================================================
    // HELPERS
    // =========================================================

    /**
     * Il VIN deve arrivare gia' normalizzato off-chain.
     * Regola suggerita:
     * - uppercase
     * - trim
     * - nessuno spazio
     * - nessun separatore extra
     */
    function computeTokenIdFromVIN(string memory normalizedVIN)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(normalizedVIN));
    }

    // =========================================================
    // ADMIN
    // =========================================================

    function authorizeIssuer(address issuer) external onlyOwner {
        if (issuer == address(0)) revert InvalidIssuer();
        authorizedIssuers[issuer] = true;
        emit IssuerAuthorized(issuer);
    }

    function revokeIssuer(address issuer) external onlyOwner {
        if (issuer == address(0)) revert InvalidIssuer();
        authorizedIssuers[issuer] = false;
        emit IssuerRevoked(issuer);
    }

    function setPassportStatus(bytes32 tokenId, PassportStatus newStatus)
        external
        onlyOwner
        onlyExistingPassport(tokenId)
    {
        passports[tokenId].status = newStatus;
        emit PassportStatusUpdated(tokenId, newStatus);
    }

    // =========================================================
    // ISSUER
    // =========================================================

    function mintVehiclePassport(
        bytes32 tokenId,
        address firstOwner,
        string calldata originMetadataURI,
        bytes32 originMetadataHash
    ) public onlyAuthorizedIssuer returns (bytes32) {
        if (firstOwner == address(0)) revert InvalidFirstOwner();
        if (passports[tokenId].exists) revert PassportAlreadyExists();

        // force = true per non imporre che il destinatario sia necessariamente UP/LSP1-aware
        _mint(firstOwner, tokenId, true, "");

        passports[tokenId] = VehiclePassport({
            exists: true,
            issuer: msg.sender,
            status: PassportStatus.Active,
            createdAt: uint64(block.timestamp),
            lastOwnershipChangeAt: uint64(block.timestamp)
        });

        originMetadataControls[tokenId] = OriginMetadataControl({
            writtenBy: msg.sender,
            updatedAt: uint64(block.timestamp),
            frozen: false
        });

        _writeOriginMetadata(
            tokenId,
            originMetadataURI,
            originMetadataHash,
            false,
            msg.sender
        );

        emit VehiclePassportMinted(tokenId, msg.sender, firstOwner);

        return tokenId;
    }

    function mintVehiclePassportFromVIN(
        string calldata normalizedVIN,
        address firstOwner,
        string calldata originMetadataURI,
        bytes32 originMetadataHash
    ) external onlyAuthorizedIssuer returns (bytes32 tokenId) {
        tokenId = computeTokenIdFromVIN(normalizedVIN);
        mintVehiclePassport(tokenId, firstOwner, originMetadataURI, originMetadataHash);
    }

    function updateOriginMetadata(
        bytes32 tokenId,
        string calldata newMetadataURI,
        bytes32 newMetadataHash
    ) external onlyExistingPassport(tokenId) {
        OriginMetadataControl storage control = originMetadataControls[tokenId];

        if (control.frozen) revert OriginMetadataAlreadyFrozen();
        if (control.writtenBy != msg.sender) revert OriginMetadataNotWritableByCaller();

        _writeOriginMetadata(
            tokenId,
            newMetadataURI,
            newMetadataHash,
            false,
            msg.sender
        );

        control.updatedAt = uint64(block.timestamp);
    }

    function freezeOriginMetadata(bytes32 tokenId)
        external
        onlyExistingPassport(tokenId)
    {
        OriginMetadataControl storage control = originMetadataControls[tokenId];

        if (control.frozen) revert OriginMetadataAlreadyFrozen();
        if (control.writtenBy != msg.sender) revert OriginMetadataNotWritableByCaller();

        control.frozen = true;
        _setDataForTokenId(tokenId, ORIGIN_METADATA_FROZEN_KEY, abi.encode(true));

        emit OriginMetadataFrozen(tokenId, msg.sender);
    }

    // =========================================================
    // OWNER AUTHORIZATIONS
    // =========================================================

    function grantWriteAuthorization(
        bytes32 tokenId,
        address operator,
        RecordCategory category,
        AuthorizationMode mode,
        uint64 validFrom,
        uint64 validUntil
    )
        external
        onlyExistingPassport(tokenId)
        onlyCurrentTokenOwner(tokenId)
        returns (uint256 authorizationId)
    {
        if (operator == address(0)) revert InvalidOperator();
        if (validUntil != 0 && validUntil < validFrom) revert InvalidValidityRange();
        if (category == RecordCategory.OwnershipTransfer) {
            revert OwnershipTransferManualRecordForbidden();
        }

        authorizationId = nextAuthorizationId++;

        authorizations[authorizationId] = WriteAuthorization({
            active: true,
            authorizationId: authorizationId,
            tokenId: tokenId,
            grantedBy: msg.sender,
            operator: operator,
            category: category,
            mode: mode,
            validFrom: validFrom,
            validUntil: validUntil,
            epoch: vehicleAuthorizationEpoch[tokenId]
        });

        authorizationIdsByVehicle[tokenId].push(authorizationId);

        emit WriteAuthorizationGranted(
            authorizationId,
            tokenId,
            msg.sender,
            operator,
            category,
            mode,
            vehicleAuthorizationEpoch[tokenId]
        );
    }

    function revokeWriteAuthorization(uint256 authorizationId) external {
        WriteAuthorization storage auth = authorizations[authorizationId];

        if (auth.authorizationId == 0) revert AuthorizationNotFound();
        if (tokenOwnerOf(auth.tokenId) != msg.sender) revert NotTokenOwner();
        if (!auth.active) revert AuthorizationInactive();

        auth.active = false;

        emit WriteAuthorizationRevoked(
            authorizationId,
            auth.tokenId,
            msg.sender
        );
    }

    function isAuthorizationCurrentlyUsable(uint256 authorizationId)
        public
        view
        returns (bool)
    {
        WriteAuthorization memory auth = authorizations[authorizationId];

        if (auth.authorizationId == 0) return false;
        if (!auth.active) return false;
        if (!passports[auth.tokenId].exists) return false;
        if (vehicleAuthorizationEpoch[auth.tokenId] != auth.epoch) return false;
        if (tokenOwnerOf(auth.tokenId) != auth.grantedBy) return false;
        if (auth.validFrom != 0 && block.timestamp < auth.validFrom) return false;
        if (auth.validUntil != 0 && block.timestamp > auth.validUntil) return false;

        return true;
    }

    // =========================================================
    // OPERATOR RECORDS
    // =========================================================

    /**
     * Opzione A:
     * - il record nasce gia' completo e frozen
     * - workStartedAt e workCompletedAt arrivano entrambi in input
     * - autorizzazione OneShot consumata alla creazione
     */
    function createServiceRecord(
        uint256 authorizationId,
        uint64 workStartedAt,
        uint64 workCompletedAt,
        uint32 odometerKm,
        string calldata recordURI,
        bytes32 recordHash,
        RecordCause cause,
        uint256 supersedesRecordId
    ) external returns (uint256 recordId) {
        WriteAuthorization storage auth = authorizations[authorizationId];

        if (auth.authorizationId == 0) revert AuthorizationNotFound();
        if (!auth.active) revert AuthorizationInactive();
        if (auth.operator != msg.sender) revert AuthorizationWrongOperator();
        if (vehicleAuthorizationEpoch[auth.tokenId] != auth.epoch) revert AuthorizationWrongEpoch();
        if (tokenOwnerOf(auth.tokenId) != auth.grantedBy) revert AuthorizationOwnerMismatch();

        if (auth.validFrom != 0 && block.timestamp < auth.validFrom) {
            revert AuthorizationNotStarted();
        }

        if (auth.validUntil != 0 && block.timestamp > auth.validUntil) {
            revert AuthorizationExpired();
        }

        if (auth.category == RecordCategory.OwnershipTransfer) {
            revert OwnershipTransferManualRecordForbidden();
        }

        if (workStartedAt == 0 || workCompletedAt < workStartedAt) {
            revert InvalidWorkDates();
        }

        if (workCompletedAt > block.timestamp) {
            revert WorkCompletionInFuture();
        }

        if (supersedesRecordId != 0) {
            if (!records[supersedesRecordId].exists) revert SupersededRecordNotFound();
            if (records[supersedesRecordId].tokenId != auth.tokenId) {
                revert SupersededRecordWrongVehicle();
            }
        }

        if (auth.mode == AuthorizationMode.OneShot) {
            auth.active = false;
        }

        recordId = nextRecordId++;

        records[recordId] = ServiceRecord({
            exists: true,
            recordId: recordId,
            tokenId: auth.tokenId,
            authorizationId: authorizationId,
            category: auth.category,
            cause: cause,
            writer: msg.sender,
            createdAt: uint64(block.timestamp),
            workStartedAt: workStartedAt,
            workCompletedAt: workCompletedAt,
            odometerKm: odometerKm,
            recordURI: recordURI,
            recordHash: recordHash,
            frozen: true,
            supersedesRecordId: supersedesRecordId,
            systemGenerated: false
        });

        recordIdsByVehicle[auth.tokenId].push(recordId);

        emit ServiceRecordCreated(
            recordId,
            auth.tokenId,
            authorizationId,
            msg.sender,
            auth.category,
            cause
        );
    }

    // =========================================================
    // VIEWS
    // =========================================================

    function getOriginMetadata(bytes32 tokenId)
        external
        view
        returns (
            string memory metadataURI,
            bytes32 metadataHash,
            bool frozen,
            address writtenBy,
            uint64 updatedAt
        )
    {
        bytes memory rawURI = getDataForTokenId(tokenId, ORIGIN_METADATA_URI_KEY);
        bytes memory rawHash = getDataForTokenId(tokenId, ORIGIN_METADATA_HASH_KEY);

        metadataURI = rawURI.length == 0 ? "" : abi.decode(rawURI, (string));
        metadataHash = rawHash.length == 0 ? bytes32(0) : abi.decode(rawHash, (bytes32));

        OriginMetadataControl memory control = originMetadataControls[tokenId];
        frozen = control.frozen;
        writtenBy = control.writtenBy;
        updatedAt = control.updatedAt;
    }

    function getAuthorizationIdsByVehicle(bytes32 tokenId)
        external
        view
        returns (uint256[] memory)
    {
        return authorizationIdsByVehicle[tokenId];
    }

    function getRecordIdsByVehicle(bytes32 tokenId)
        external
        view
        returns (uint256[] memory)
    {
        return recordIdsByVehicle[tokenId];
    }

    function getCurrentOwner(bytes32 tokenId)
        external
        view
        returns (address)
    {
        return tokenOwnerOf(tokenId);
    }

    // =========================================================
    // INTERNALS
    // =========================================================

    function _writeOriginMetadata(
        bytes32 tokenId,
        string memory metadataURI,
        bytes32 metadataHash,
        bool frozen,
        address writer
    ) internal {
        _setDataForTokenId(tokenId, ORIGIN_METADATA_URI_KEY, abi.encode(metadataURI));
        _setDataForTokenId(tokenId, ORIGIN_METADATA_HASH_KEY, abi.encode(metadataHash));
        _setDataForTokenId(tokenId, ORIGIN_METADATA_FROZEN_KEY, abi.encode(frozen));

        emit OriginMetadataUpdated(tokenId, writer, metadataURI, metadataHash);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        bytes32 tokenId,
        bool force,
        bytes memory data
    ) internal virtual override {
        super._afterTokenTransfer(from, to, tokenId, force, data);

        // ignora mint
        if (from == address(0) || from == to) {
            return;
        }

        // burn non usato in questa V1
        if (to == address(0)) {
            return;
        }

        passports[tokenId].lastOwnershipChangeAt = uint64(block.timestamp);

        vehicleAuthorizationEpoch[tokenId] += 1;
        emit VehicleAuthorizationEpochIncremented(
            tokenId,
            vehicleAuthorizationEpoch[tokenId]
        );

        _createOwnershipTransferRecord(tokenId, from, to);
    }

    function _createOwnershipTransferRecord(
        bytes32 tokenId,
        address from,
        address to
    ) internal {
        uint256 recordId = nextRecordId++;

        records[recordId] = ServiceRecord({
            exists: true,
            recordId: recordId,
            tokenId: tokenId,
            authorizationId: 0,
            category: RecordCategory.OwnershipTransfer,
            cause: RecordCause.None,
            writer: address(0),
            createdAt: uint64(block.timestamp),
            workStartedAt: uint64(block.timestamp),
            workCompletedAt: uint64(block.timestamp),
            odometerKm: 0,
            recordURI: "",
            recordHash: bytes32(0),
            frozen: true,
            supersedesRecordId: 0,
            systemGenerated: true
        });

        recordIdsByVehicle[tokenId].push(recordId);

        emit ServiceRecordCreated(
            recordId,
            tokenId,
            0,
            address(0),
            RecordCategory.OwnershipTransfer,
            RecordCause.None
        );

        emit OwnershipTransferRecordCreated(recordId, tokenId, from, to);
    }
}