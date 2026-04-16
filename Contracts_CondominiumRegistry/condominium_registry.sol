// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// LUKSO
import {
    LSP8Mintable
} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/presets/LSP8Mintable.sol";

import {
    _LSP8_TOKENID_FORMAT_NUMBER
} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8Constants.sol";

import {
    _LSP4_TOKEN_TYPE_COLLECTION
} from "@lukso/lsp-smart-contracts/contracts/LSP4DigitalAssetMetadata/LSP4Constants.sol";

// OpenZeppelin
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title CondominiumRegistryLSP8
 * @notice Registro LSP8 per condomini.
 *
 * Modello:
 * - 1 tokenId LSP8 = 1 condominio
 * - deploy contratto: ChainIntegrate
 * - mint: solo creator autorizzati
 * - ruoli operativi: solo Universal Profile (o account che supportano l'interfaceId configurato)
 *
 * Nota:
 * - Questo contratto NON gestisce votazioni, millesimi, contabilità o quorum on-chain.
 * - Gestisce identità condominio, delibere, lavori, fornitori, eventi cronologici.
 */
contract CondominiumRegistryLSP8 is LSP8Mintable {
    // =============================================================
    // CONFIG
    // =============================================================

    /// @notice InterfaceId che un UP / profile account deve supportare.
    /// Va impostato al deploy con l'interfaceId corretto del tuo stack LUKSO.
    bytes4 public immutable requiredProfileInterfaceId;

    // =============================================================
    // ENUMS
    // =============================================================

    enum ResolutionCategory {
        Generic,
        OrdinaryWorks,
        ExtraordinaryWorks,
        Heating,
        AnnualBudget,
        HeatingBudget,
        Administrator,
        Regulation,
        Other
    }

    enum WorkType {
        Generic,
        FixedTerm
    }

    enum WorkStatus {
        Planned,
        Approved,
        InProgress,
        Completed,
        Closed,
        Suspended,
        Cancelled
    }

    enum EventType {
        AssembleaConvocata,
        VerbalePubblicato,
        DeliberaPubblicata,
        BilancioPubblicato,
        FornitoreSelezionato,
        LavoriAvviati,
        LavoriConclusi,
        ContestazioneAperta,
        ContestazioneChiusa,
        AmministratoreAggiornato
    }

    // =============================================================
    // STRUCTS
    // =============================================================

    struct CondominiumData {
        bytes32 tokenId;
        address adminUP;
        string name;
        string location;
        uint256 createdAt;
        bool active;
    }

    struct ResolutionItem {
        uint256 id;
        bytes32 tokenId;
        ResolutionCategory category;
        string title;
        uint256 createdAt;
        bool approved;
        string dataURI;
        bytes32 dataHash;
        address createdBy;
    }

    struct Contractor {
        uint256 id;
        string name;
        address walletUP; // opzionale, ma se presente deve essere UP
        string metadataURI;
        uint256 createdAt;
        bool active;
    }

    struct WorkItem {
        uint256 id;
        bytes32 tokenId;
        uint256 resolutionId; // 0 se non collegato a delibera
        uint256 contractorId; // 0 se non assegnato

        string title;
        string category;

        WorkType workType;
        WorkStatus status;

        uint256 createdAt;

        uint256 plannedStartDate;
        uint256 plannedEndDate; // obbligatoria per FixedTerm

        uint256 actualStartDate;
        uint256 actualEndDate;
    }

    struct RegistryEvent {
        uint256 id;
        bytes32 tokenId;

        uint256 relatedResolutionId;
        uint256 relatedWorkId;

        EventType eventType;
        uint256 timestamp;

        string category;
        string title;

        string dataURI;
        bytes32 dataHash;

        address createdBy;
    }

    // =============================================================
    // STORAGE
    // =============================================================

    mapping(address => bool) public authorizedCreators;

    mapping(bytes32 => CondominiumData) public condominiumData;
    mapping(bytes32 => bool) public condominiumExists;

    mapping(bytes32 => mapping(uint256 => ResolutionItem)) private _resolutionsByToken;
    mapping(bytes32 => uint256) public resolutionCountByToken;

    mapping(uint256 => Contractor) public contractors;
    uint256 public contractorCount;

    mapping(bytes32 => mapping(uint256 => WorkItem)) private _worksByToken;
    mapping(bytes32 => uint256) public workCountByToken;

    mapping(bytes32 => mapping(uint256 => RegistryEvent)) private _eventsByToken;
    mapping(bytes32 => uint256) public eventCountByToken;

    // =============================================================
    // SOLIDITY EVENTS
    // =============================================================

    event AuthorizedCreatorSet(address indexed creator, bool allowed);

    event CondominiumMinted(
        bytes32 indexed tokenId,
        address indexed adminUP,
        string name,
        string location
    );

    event CondominiumAdminUpdated(
        bytes32 indexed tokenId,
        address indexed oldAdminUP,
        address indexed newAdminUP
    );

    event ResolutionCreated(
        bytes32 indexed tokenId,
        uint256 indexed resolutionId,
        ResolutionCategory category,
        string title
    );

    event ContractorCreated(
        uint256 indexed contractorId,
        string name,
        address indexed walletUP
    );

    event WorkItemCreated(
        bytes32 indexed tokenId,
        uint256 indexed workId,
        uint256 indexed resolutionId,
        string title
    );

    event WorkContractorAssigned(
        bytes32 indexed tokenId,
        uint256 indexed workId,
        uint256 indexed contractorId
    );

    event WorkStatusUpdated(
        bytes32 indexed tokenId,
        uint256 indexed workId,
        WorkStatus newStatus,
        uint256 actualStartDate,
        uint256 actualEndDate
    );

    event RegistryEventAdded(
        bytes32 indexed tokenId,
        uint256 indexed eventId,
        EventType eventType,
        uint256 relatedResolutionId,
        uint256 relatedWorkId
    );

    // =============================================================
    // MODIFIERS
    // =============================================================

    modifier onlyAuthorizedCreator() {
        require(authorizedCreators[msg.sender], "Not authorized creator");
        _;
    }

    modifier onlyCondominiumAdmin(bytes32 tokenId) {
        require(condominiumExists[tokenId], "Unknown condominium");
        require(condominiumData[tokenId].adminUP == msg.sender, "Not condominium admin");
        _;
    }

    modifier onlyExistingCondominium(bytes32 tokenId) {
        require(condominiumExists[tokenId], "Unknown condominium");
        _;
    }

    modifier onlyActiveCondominium(bytes32 tokenId) {
        require(condominiumExists[tokenId], "Unknown condominium");
        require(condominiumData[tokenId].active, "Condominium inactive");
        _;
    }

    // =============================================================
    // CONSTRUCTOR
    // =============================================================

    constructor(
        string memory collectionName_,
        string memory collectionSymbol_,
        address contractOwner_,
        bytes4 requiredProfileInterfaceId_
    )
        LSP8Mintable(
            collectionName_,
            collectionSymbol_,
            contractOwner_,
            _LSP4_TOKEN_TYPE_COLLECTION,
            _LSP8_TOKENID_FORMAT_NUMBER
        )
    {
        require(contractOwner_ != address(0), "Invalid contract owner");
        requiredProfileInterfaceId = requiredProfileInterfaceId_;
    }

    // =============================================================
    // ADMIN / CREATOR CONTROL
    // =============================================================

    function setAuthorizedCreator(address creatorUP, bool allowed) external onlyOwner {
        _requireProfile(creatorUP);
        authorizedCreators[creatorUP] = allowed;
        emit AuthorizedCreatorSet(creatorUP, allowed);
    }

    // =============================================================
    // CONDOMINIUM
    // =============================================================

    function mintCondominium(
        bytes32 tokenId,
        address adminUP,
        string calldata condoName,
        string calldata location
    ) external onlyAuthorizedCreator {
        require(!condominiumExists[tokenId], "Token already used");
        require(bytes(condoName).length > 0, "Name required");

        _requireProfile(adminUP);

        // LSP8 token minted directly to the admin UP
        _mint(adminUP, tokenId, true, "");

        condominiumExists[tokenId] = true;
        condominiumData[tokenId] = CondominiumData({
            tokenId: tokenId,
            adminUP: adminUP,
            name: condoName,
            location: location,
            createdAt: block.timestamp,
            active: true
        });

        emit CondominiumMinted(tokenId, adminUP, condoName, location);
    }

    function setCondominiumActive(
        bytes32 tokenId,
        bool active
    ) external onlyCondominiumAdmin(tokenId) {
        condominiumData[tokenId].active = active;
    }

    function transferAdministration(
        bytes32 tokenId,
        address newAdminUP,
        string calldata dataURI,
        bytes32 dataHash
    )
        external
        onlyCondominiumAdmin(tokenId)
        onlyActiveCondominium(tokenId)
    {
        _requireProfile(newAdminUP);
        require(newAdminUP != condominiumData[tokenId].adminUP, "Already current admin");

        address oldAdmin = condominiumData[tokenId].adminUP;
        condominiumData[tokenId].adminUP = newAdminUP;

        emit CondominiumAdminUpdated(tokenId, oldAdmin, newAdminUP);

        _addRegistryEventInternal(
            tokenId,
            0,
            0,
            EventType.AmministratoreAggiornato,
            "administrator",
            "Administrator updated",
            dataURI,
            dataHash
        );
    }

    // =============================================================
    // RESOLUTIONS
    // =============================================================

    function createResolution(
        bytes32 tokenId,
        ResolutionCategory category,
        string calldata title,
        bool approved,
        string calldata dataURI,
        bytes32 dataHash
    )
        external
        onlyCondominiumAdmin(tokenId)
        onlyActiveCondominium(tokenId)
        returns (uint256 resolutionId)
    {
        require(bytes(title).length > 0, "Title required");

        resolutionId = ++resolutionCountByToken[tokenId];

        _resolutionsByToken[tokenId][resolutionId] = ResolutionItem({
            id: resolutionId,
            tokenId: tokenId,
            category: category,
            title: title,
            createdAt: block.timestamp,
            approved: approved,
            dataURI: dataURI,
            dataHash: dataHash,
            createdBy: msg.sender
        });

        emit ResolutionCreated(tokenId, resolutionId, category, title);

        _addRegistryEventInternal(
            tokenId,
            resolutionId,
            0,
            EventType.DeliberaPubblicata,
            _resolutionCategoryToString(category),
            title,
            dataURI,
            dataHash
        );
    }

    function getResolution(
        bytes32 tokenId,
        uint256 resolutionId
    ) external view onlyExistingCondominium(tokenId) returns (ResolutionItem memory) {
        require(
            resolutionId > 0 && resolutionId <= resolutionCountByToken[tokenId],
            "Invalid resolutionId"
        );
        return _resolutionsByToken[tokenId][resolutionId];
    }

    // =============================================================
    // CONTRACTORS
    // =============================================================

    function createContractor(
        string calldata name,
        address walletUP,
        string calldata metadataURI
    ) external onlyOwner returns (uint256 contractorId) {
        require(bytes(name).length > 0, "Name required");

        if (walletUP != address(0)) {
            _requireProfile(walletUP);
        }

        contractorId = ++contractorCount;

        contractors[contractorId] = Contractor({
            id: contractorId,
            name: name,
            walletUP: walletUP,
            metadataURI: metadataURI,
            createdAt: block.timestamp,
            active: true
        });

        emit ContractorCreated(contractorId, name, walletUP);
    }

    function setContractorActive(uint256 contractorId, bool active) external onlyOwner {
        require(contractors[contractorId].id != 0, "Unknown contractor");
        contractors[contractorId].active = active;
    }

    // =============================================================
    // WORK ITEMS
    // =============================================================

    function createWorkItem(
        bytes32 tokenId,
        uint256 resolutionId,
        uint256 contractorId,
        string calldata title,
        string calldata category,
        WorkType workType,
        uint256 plannedStartDate,
        uint256 plannedEndDate
    )
        external
        onlyCondominiumAdmin(tokenId)
        onlyActiveCondominium(tokenId)
        returns (uint256 workId)
    {
        require(bytes(title).length > 0, "Title required");

        if (resolutionId != 0) {
            require(
                resolutionId <= resolutionCountByToken[tokenId],
                "Invalid resolutionId"
            );
        }

        if (contractorId != 0) {
            require(contractors[contractorId].id != 0, "Invalid contractorId");
            require(contractors[contractorId].active, "Inactive contractor");
        }

        require(
            workType != WorkType.FixedTerm || plannedEndDate != 0,
            "Fixed-term work requires planned end date"
        );

        if (plannedStartDate != 0 && plannedEndDate != 0) {
            require(plannedEndDate >= plannedStartDate, "Invalid planned dates");
        }

        workId = ++workCountByToken[tokenId];

        _worksByToken[tokenId][workId] = WorkItem({
            id: workId,
            tokenId: tokenId,
            resolutionId: resolutionId,
            contractorId: contractorId,
            title: title,
            category: category,
            workType: workType,
            status: WorkStatus.Planned,
            createdAt: block.timestamp,
            plannedStartDate: plannedStartDate,
            plannedEndDate: plannedEndDate,
            actualStartDate: 0,
            actualEndDate: 0
        });

        emit WorkItemCreated(tokenId, workId, resolutionId, title);
    }

    function assignContractorToWork(
        bytes32 tokenId,
        uint256 workId,
        uint256 contractorId,
        string calldata dataURI,
        bytes32 dataHash
    )
        external
        onlyCondominiumAdmin(tokenId)
        onlyActiveCondominium(tokenId)
    {
        require(workId > 0 && workId <= workCountByToken[tokenId], "Invalid workId");
        require(contractors[contractorId].id != 0, "Invalid contractorId");
        require(contractors[contractorId].active, "Inactive contractor");

        _worksByToken[tokenId][workId].contractorId = contractorId;

        emit WorkContractorAssigned(tokenId, workId, contractorId);

        _addRegistryEventInternal(
            tokenId,
            _worksByToken[tokenId][workId].resolutionId,
            workId,
            EventType.FornitoreSelezionato,
            "contractor",
            contractors[contractorId].name,
            dataURI,
            dataHash
        );
    }

    function updateWorkStatus(
        bytes32 tokenId,
        uint256 workId,
        WorkStatus newStatus,
        uint256 actualStartDate,
        uint256 actualEndDate,
        string calldata dataURI,
        bytes32 dataHash
    )
        external
        onlyCondominiumAdmin(tokenId)
        onlyActiveCondominium(tokenId)
    {
        require(workId > 0 && workId <= workCountByToken[tokenId], "Invalid workId");

        WorkItem storage work = _worksByToken[tokenId][workId];

        if (actualStartDate != 0) {
            work.actualStartDate = actualStartDate;
        }

        if (actualEndDate != 0) {
            work.actualEndDate = actualEndDate;
        }

        if (work.actualStartDate != 0 && work.actualEndDate != 0) {
            require(work.actualEndDate >= work.actualStartDate, "Invalid actual dates");
        }

        work.status = newStatus;

        emit WorkStatusUpdated(
            tokenId,
            workId,
            newStatus,
            work.actualStartDate,
            work.actualEndDate
        );

        if (newStatus == WorkStatus.InProgress) {
            _addRegistryEventInternal(
                tokenId,
                work.resolutionId,
                workId,
                EventType.LavoriAvviati,
                work.category,
                work.title,
                dataURI,
                dataHash
            );
        } else if (newStatus == WorkStatus.Completed || newStatus == WorkStatus.Closed) {
            _addRegistryEventInternal(
                tokenId,
                work.resolutionId,
                workId,
                EventType.LavoriConclusi,
                work.category,
                work.title,
                dataURI,
                dataHash
            );
        }
    }

    function getWorkItem(
        bytes32 tokenId,
        uint256 workId
    ) external view onlyExistingCondominium(tokenId) returns (WorkItem memory) {
        require(workId > 0 && workId <= workCountByToken[tokenId], "Invalid workId");
        return _worksByToken[tokenId][workId];
    }

    // =============================================================
    // REGISTRY EVENTS
    // =============================================================

    function addEvent(
        bytes32 tokenId,
        uint256 relatedResolutionId,
        uint256 relatedWorkId,
        EventType eventType,
        string calldata category,
        string calldata title,
        string calldata dataURI,
        bytes32 dataHash
    )
        external
        onlyCondominiumAdmin(tokenId)
        onlyActiveCondominium(tokenId)
        returns (uint256 eventId)
    {
        if (relatedResolutionId != 0) {
            require(
                relatedResolutionId <= resolutionCountByToken[tokenId],
                "Invalid relatedResolutionId"
            );
        }

        if (relatedWorkId != 0) {
            require(
                relatedWorkId <= workCountByToken[tokenId],
                "Invalid relatedWorkId"
            );
        }

        eventId = _addRegistryEventInternal(
            tokenId,
            relatedResolutionId,
            relatedWorkId,
            eventType,
            category,
            title,
            dataURI,
            dataHash
        );
    }

    function getEvent(
        bytes32 tokenId,
        uint256 eventId
    ) external view onlyExistingCondominium(tokenId) returns (RegistryEvent memory) {
        require(eventId > 0 && eventId <= eventCountByToken[tokenId], "Invalid eventId");
        return _eventsByToken[tokenId][eventId];
    }

    function _addRegistryEventInternal(
        bytes32 tokenId,
        uint256 relatedResolutionId,
        uint256 relatedWorkId,
        EventType eventType,
        string memory category,
        string memory title,
        string memory dataURI,
        bytes32 dataHash
    ) internal returns (uint256 eventId) {
        eventId = ++eventCountByToken[tokenId];

        _eventsByToken[tokenId][eventId] = RegistryEvent({
            id: eventId,
            tokenId: tokenId,
            relatedResolutionId: relatedResolutionId,
            relatedWorkId: relatedWorkId,
            eventType: eventType,
            timestamp: block.timestamp,
            category: category,
            title: title,
            dataURI: dataURI,
            dataHash: dataHash,
            createdBy: msg.sender
        });

        emit RegistryEventAdded(
            tokenId,
            eventId,
            eventType,
            relatedResolutionId,
            relatedWorkId
        );
    }

    // =============================================================
    // HELPERS
    // =============================================================

    function getCondominium(
        bytes32 tokenId
    ) external view onlyExistingCondominium(tokenId) returns (CondominiumData memory) {
        return condominiumData[tokenId];
    }

    function _resolutionCategoryToString(
        ResolutionCategory category
    ) internal pure returns (string memory) {
        if (category == ResolutionCategory.Generic) return "generic";
        if (category == ResolutionCategory.OrdinaryWorks) return "ordinary_works";
        if (category == ResolutionCategory.ExtraordinaryWorks) return "extraordinary_works";
        if (category == ResolutionCategory.Heating) return "heating";
        if (category == ResolutionCategory.AnnualBudget) return "annual_budget";
        if (category == ResolutionCategory.HeatingBudget) return "heating_budget";
        if (category == ResolutionCategory.Administrator) return "administrator";
        if (category == ResolutionCategory.Regulation) return "regulation";
        return "other";
    }

    function _requireProfile(address candidate) internal view {
        require(candidate != address(0), "Zero address");
        require(candidate.code.length > 0, "Must be contract account");

        bool ok;
        try IERC165(candidate).supportsInterface(requiredProfileInterfaceId) returns (bool supported) {
            ok = supported;
        } catch {
            ok = false;
        }

        require(ok, "Address is not a supported profile");
    }
}