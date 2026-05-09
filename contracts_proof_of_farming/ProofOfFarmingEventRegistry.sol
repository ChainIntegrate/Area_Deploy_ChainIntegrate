// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
    Proof of Farming - EventRegistry V1

    Registro eventi agricoli collegati ai Farm Passport.
*/

interface IProofOfFarmingPassport {

    function farmExists(
        bytes32 farmId
    ) external view returns (bool);

    function tokenOwnerOf(
        bytes32 tokenId
    ) external view returns (address);
}

contract ProofOfFarmingEventRegistry {

    enum EventType {
        None,
        CropStarted,
        SoilWork,
        Fertilization,
        Treatment,
        Irrigation,
        Harvest,
        SoilAnalysis,
        Biodiversity,
        Energy,
        RecoveredWater,
        AgriculturalWaste,
        Certification,
        Audit,
        NonCompliance,
        NonComplianceClosed,
        BadgeAssigned,
        BadgeRevoked,
        ScoreUpdated
    }

    enum EventStatus {
        None,
        Registered,
        Validated,
        Revoked
    }

    struct FarmEvent {
        bytes32 eventId;
        bytes32 farmId;
        bytes32 plotId;
        EventType eventType;
        EventStatus status;
        bytes32 dataHash;
        address operator;
        address validator;
        uint256 createdAt;
        uint256 validatedAt;
    }

    address public owner;

    IProofOfFarmingPassport public passport;

    mapping(bytes32 => FarmEvent) private eventsById;

    mapping(bytes32 => bool) public eventExists;

    mapping(bytes32 => mapping(address => bool))
        public farmOperators;

    mapping(address => bool)
        public validators;

    event FarmOperatorUpdated(
        bytes32 indexed farmId,
        address indexed operator,
        bool active
    );

    event ValidatorUpdated(
        address indexed validator,
        bool active
    );

    event FarmEventRegistered(
        bytes32 indexed farmId,
        bytes32 indexed plotId,
        bytes32 indexed eventId,
        EventType eventType,
        bytes32 dataHash,
        address operator,
        uint256 timestamp
    );

    event FarmEventValidated(
        bytes32 indexed farmId,
        bytes32 indexed eventId,
        address validator,
        uint256 timestamp
    );

    event FarmEventRevoked(
        bytes32 indexed farmId,
        bytes32 indexed eventId,
        address revokedBy,
        uint256 timestamp
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyFarmOwner(
        bytes32 farmId
    ) {
        require(
            passport.tokenOwnerOf(farmId) == msg.sender,
            "Not farm owner"
        );
        _;
    }

    modifier onlyFarmOperator(
        bytes32 farmId
    ) {
        require(
            passport.tokenOwnerOf(farmId) == msg.sender ||
            farmOperators[farmId][msg.sender],
            "Not farm operator"
        );
        _;
    }

    modifier onlyValidator() {
        require(
            validators[msg.sender] ||
            msg.sender == owner,
            "Not validator"
        );
        _;
    }

    constructor(
        address passportAddress
    ) {

        require(
            passportAddress != address(0),
            "Invalid passport address"
        );

        owner = msg.sender;

        passport = IProofOfFarmingPassport(
            passportAddress
        );
    }

    function setFarmOperator(
        bytes32 farmId,
        address operator,
        bool active
    ) external onlyFarmOwner(farmId) {

        require(
            passport.farmExists(farmId),
            "Farm does not exist"
        );

        require(
            operator != address(0),
            "Invalid operator"
        );

        farmOperators[farmId][operator] = active;

        emit FarmOperatorUpdated(
            farmId,
            operator,
            active
        );
    }

    function setValidator(
        address validator,
        bool active
    ) external onlyOwner {

        require(
            validator != address(0),
            "Invalid validator"
        );

        validators[validator] = active;

        emit ValidatorUpdated(
            validator,
            active
        );
    }

    function registerEvent(
        bytes32 farmId,
        bytes32 plotId,
        bytes32 eventId,
        EventType eventType,
        bytes32 dataHash
    ) external onlyFarmOperator(farmId) {

        require(
            passport.farmExists(farmId),
            "Farm does not exist"
        );

        require(
            plotId != bytes32(0),
            "Invalid plotId"
        );

        require(
            eventId != bytes32(0),
            "Invalid eventId"
        );

        require(
            dataHash != bytes32(0),
            "Invalid dataHash"
        );

        require(
            eventType != EventType.None,
            "Invalid event type"
        );

        require(
            !eventExists[eventId],
            "Event already exists"
        );

        eventExists[eventId] = true;

        eventsById[eventId] = FarmEvent({
            eventId: eventId,
            farmId: farmId,
            plotId: plotId,
            eventType: eventType,
            status: EventStatus.Registered,
            dataHash: dataHash,
            operator: msg.sender,
            validator: address(0),
            createdAt: block.timestamp,
            validatedAt: 0
        });

        emit FarmEventRegistered(
            farmId,
            plotId,
            eventId,
            eventType,
            dataHash,
            msg.sender,
            block.timestamp
        );
    }

    function validateEvent(
        bytes32 eventId
    ) external onlyValidator {

        require(
            eventExists[eventId],
            "Event does not exist"
        );

        FarmEvent storage farmEvent =
            eventsById[eventId];

        require(
            farmEvent.status ==
            EventStatus.Registered,
            "Event not registrable"
        );

        farmEvent.status =
            EventStatus.Validated;

        farmEvent.validator = msg.sender;

        farmEvent.validatedAt =
            block.timestamp;

        emit FarmEventValidated(
            farmEvent.farmId,
            eventId,
            msg.sender,
            block.timestamp
        );
    }

    function revokeEvent(
        bytes32 eventId
    ) external onlyValidator {

        require(
            eventExists[eventId],
            "Event does not exist"
        );

        FarmEvent storage farmEvent =
            eventsById[eventId];

        require(
            farmEvent.status !=
            EventStatus.Revoked,
            "Already revoked"
        );

        farmEvent.status =
            EventStatus.Revoked;

        emit FarmEventRevoked(
            farmEvent.farmId,
            eventId,
            msg.sender,
            block.timestamp
        );
    }

    function getEvent(
        bytes32 eventId
    ) external view returns (
        FarmEvent memory
    ) {

        require(
            eventExists[eventId],
            "Event does not exist"
        );

        return eventsById[eventId];
    }
}
