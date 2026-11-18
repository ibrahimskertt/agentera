// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal read interface of the official Agent ID contract on BNB Chain
///         (SPACE ID Agent ID, ERC-721, non-transferable):
///         0x60b9262456de011f7d15a54cdd8c48baaa8b022f
///         An address holds an Agent ID when balanceOf(address) > 0.
interface IAgentID {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title AgentPass — the on-chain operator badge for verified Agent ID holders
/// @notice A free, soulbound (non-transferable) ERC-721 badge that can only be
///         claimed by an address that holds an Agent ID. Agent ID ownership is
///         verified on-chain against the official Agent ID contract at claim
///         and check-in time — no server, no manual review.
/// @dev    This contract has NO owner and NO admin functions. It cannot mint
///         outside `claimBadge`, cannot pause, cannot take fees, and holds no
///         user funds. There is nothing to renounce because no privileged role
///         exists in the first place.
contract AgentPass {
    // ── ERC-721 metadata ────────────────────────────────────────────────────
    string public constant name = "AgentPass";
    string public constant symbol = "APASS";

    // ── Agent ID gate ───────────────────────────────────────────────────────
    IAgentID public immutable agentID;

    // ── Badge state ─────────────────────────────────────────────────────────
    uint256 private _nextTokenId = 1;
    uint256 public totalClaimers;

    mapping(address => uint256) private _badgeOf; // claimer => tokenId (0 = none)
    mapping(uint256 => address) private _ownerOf; // tokenId => claimer

    // ── Check-in state ──────────────────────────────────────────────────────
    mapping(address => uint256) public lastCheckInDay; // day index of last check-in
    mapping(address => uint256) public currentStreak; // consecutive-day streak
    mapping(address => uint256) public checkInCount; // lifetime check-ins

    // ── Events ──────────────────────────────────────────────────────────────
    event BadgeClaimed(address indexed claimer, uint256 indexed tokenId);
    event CheckedIn(address indexed claimer, uint256 streak, uint256 totalCheckIns);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    // ── Errors ──────────────────────────────────────────────────────────────
    error NoAgentID();
    error AlreadyClaimed();
    error NoBadge();
    error AlreadyCheckedInToday();
    error Soulbound();
    error NonexistentToken();
    error ZeroAddress();

    constructor(address agentIDContract) {
        if (agentIDContract == address(0)) revert ZeroAddress();
        agentID = IAgentID(agentIDContract);
    }

    // ── Core: claim ─────────────────────────────────────────────────────────
    /// @notice Claim the AgentPass badge. Requires holding an Agent ID.
    ///         One badge per address, free, non-transferable.
    function claimBadge() external returns (uint256 tokenId) {
        if (agentID.balanceOf(msg.sender) == 0) revert NoAgentID();
        if (_badgeOf[msg.sender] != 0) revert AlreadyClaimed();

        tokenId = _nextTokenId++;
        _badgeOf[msg.sender] = tokenId;
        _ownerOf[tokenId] = msg.sender;
        totalClaimers += 1;

        emit Transfer(address(0), msg.sender, tokenId);
        emit BadgeClaimed(msg.sender, tokenId);
    }

    // ── Core: daily check-in ────────────────────────────────────────────────
    /// @notice Check in once per day. Builds a consecutive-day streak;
    ///         a missed day resets the streak to 1. Badge holders only.
    function checkIn() external {
        if (_badgeOf[msg.sender] == 0) revert NoBadge();

        uint256 today = block.timestamp / 1 days;
        uint256 last = lastCheckInDay[msg.sender];
        bool hasCheckedInBefore = checkInCount[msg.sender] > 0;
        if (hasCheckedInBefore && last == today) revert AlreadyCheckedInToday();

        currentStreak[msg.sender] = (hasCheckedInBefore && last == today - 1) ? currentStreak[msg.sender] + 1 : 1;
        lastCheckInDay[msg.sender] = today;
        checkInCount[msg.sender] += 1;

        emit CheckedIn(msg.sender, currentStreak[msg.sender], checkInCount[msg.sender]);
    }

    // ── Views ───────────────────────────────────────────────────────────────
    function hasBadge(address account) external view returns (bool) {
        return _badgeOf[account] != 0;
    }

    function badgeOf(address account) external view returns (uint256) {
        return _badgeOf[account];
    }

    function holdsAgentID(address account) external view returns (bool) {
        return agentID.balanceOf(account) > 0;
    }

    // ── ERC-721 surface ─────────────────────────────────────────────────────
    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        return _badgeOf[owner] == 0 ? 0 : 1;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _ownerOf[tokenId];
        if (owner == address(0)) revert NonexistentToken();
        return owner;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        if (_ownerOf[tokenId] == address(0)) revert NonexistentToken();
        return string(
            abi.encodePacked(
                "data:application/json;utf8,{\"name\":\"AgentPass Badge #",
                _toString(tokenId),
                "\",\"description\":\"Soulbound operator badge for verified Agent ID holders on BNB Chain. "
                "Claimed only after on-chain verification against the official Agent ID contract.\","
                "\"attributes\":[{\"trait_type\":\"Credential\",\"value\":\"Verified Agent ID Operator\"}]}"
            )
        );
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x80ac58cd // ERC-721
            || interfaceId == 0x5b5e139f // ERC-721 metadata
            || interfaceId == 0x01ffc9a7; // ERC-165
    }

    // ── Soulbound: every transfer / approval path reverts ──────────────────
    function transferFrom(address, address, uint256) external pure {
        revert Soulbound();
    }

    function safeTransferFrom(address, address, uint256) external pure {
        revert Soulbound();
    }

    function safeTransferFrom(address, address, uint256, bytes calldata) external pure {
        revert Soulbound();
    }

    function approve(address, uint256) external pure {
        revert Soulbound();
    }

    function setApprovalForAll(address, bool) external pure {
        revert Soulbound();
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        if (_ownerOf[tokenId] == address(0)) revert NonexistentToken();
        return address(0);
    }

    function isApprovedForAll(address, address) external pure returns (bool) {
        return false;
    }

    // ── Helpers ─────────────────────────────────────────────────────────────
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
