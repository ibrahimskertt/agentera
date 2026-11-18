// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AgenTera, IAgentID} from "../src/AgenTera.sol";

// ── Minimal Foundry cheatcode interface (no forge-std dependency) ──────────
interface Vm {
    function prank(address msgSender) external;
    function warp(uint256 newTimestamp) external;
    function expectRevert(bytes4 revertData) external;
    function expectRevert() external;
}

// ── Tiny assertion base ─────────────────────────────────────────────────────
contract TestBase {
    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function assertTrue(bool cond, string memory msg_) internal pure {
        if (!cond) revert(msg_);
    }

    function assertEq(uint256 a, uint256 b, string memory msg_) internal pure {
        if (a != b) revert(msg_);
    }

    function assertEq(address a, address b, string memory msg_) internal pure {
        if (a != b) revert(msg_);
    }
}

// ── Mock of the official Agent ID contract ──────────────────────────────────
contract MockAgentID is IAgentID {
    mapping(address => uint256) private _balances;

    function setBalance(address who, uint256 amount) external {
        _balances[who] = amount;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _balances[owner];
    }
}

contract AgenTeraTest is TestBase {
    MockAgentID internal mockID;
    AgenTera internal pass;

    address internal alice = address(0xA11CE); // holds an Agent ID
    address internal bob = address(0xB0B); // holds no Agent ID
    address internal carol = address(0xCA401); // holds an Agent ID

    function setUp() public {
        mockID = new MockAgentID();
        pass = new AgenTera(address(mockID));
        mockID.setBalance(alice, 1);
        mockID.setBalance(carol, 1);
    }

    function test_ClaimByHolder() public {
        vm.prank(alice);
        uint256 tokenId = pass.claimBadge();
        assertEq(tokenId, 1, "first tokenId must be 1");
        assertTrue(pass.hasBadge(alice), "alice must have badge");
        assertEq(pass.balanceOf(alice), 1, "alice balance must be 1");
        assertEq(pass.ownerOf(1), alice, "ownerOf(1) must be alice");
        assertEq(pass.totalClaimers(), 1, "totalClaimers must be 1");
        assertEq(pass.badgeOf(alice), 1, "badgeOf(alice) must be 1");
    }

    function test_ClaimByNonHolderReverts() public {
        vm.prank(bob);
        vm.expectRevert(AgenTera.NoAgentID.selector);
        pass.claimBadge();
    }

    function test_DoubleClaimReverts() public {
        vm.prank(alice);
        pass.claimBadge();
        vm.prank(alice);
        vm.expectRevert(AgenTera.AlreadyClaimed.selector);
        pass.claimBadge();
    }

    function test_TwoHoldersSequentialIds() public {
        vm.prank(alice);
        uint256 id1 = pass.claimBadge();
        vm.prank(carol);
        uint256 id2 = pass.claimBadge();
        assertEq(id1, 1, "alice id 1");
        assertEq(id2, 2, "carol id 2");
        assertEq(pass.totalClaimers(), 2, "two claimers");
    }

    function test_SoulboundTransferReverts() public {
        vm.prank(alice);
        pass.claimBadge();
        vm.prank(alice);
        vm.expectRevert(AgenTera.Soulbound.selector);
        pass.transferFrom(alice, bob, 1);
    }

    function test_SoulboundApproveReverts() public {
        vm.prank(alice);
        pass.claimBadge();
        vm.prank(alice);
        vm.expectRevert(AgenTera.Soulbound.selector);
        pass.approve(bob, 1);
    }

    function test_CheckInFlowAndStreaks() public {
        vm.prank(alice);
        pass.claimBadge();

        // Day 0: first check-in, streak 1
        vm.prank(alice);
        pass.checkIn();
        assertEq(pass.currentStreak(alice), 1, "streak 1 after first check-in");
        assertEq(pass.checkInCount(alice), 1, "count 1");

        // Same day again: revert
        vm.prank(alice);
        vm.expectRevert(AgenTera.AlreadyCheckedInToday.selector);
        pass.checkIn();

        // Next day: streak 2
        vm.warp(block.timestamp + 1 days);
        vm.prank(alice);
        pass.checkIn();
        assertEq(pass.currentStreak(alice), 2, "streak 2 on consecutive day");
        assertEq(pass.checkInCount(alice), 2, "count 2");

        // Skip a day: streak resets to 1
        vm.warp(block.timestamp + 2 days);
        vm.prank(alice);
        pass.checkIn();
        assertEq(pass.currentStreak(alice), 1, "streak resets after a gap");
        assertEq(pass.checkInCount(alice), 3, "count 3");
    }

    function test_CheckInWithoutBadgeReverts() public {
        vm.prank(carol); // holds an Agent ID but never claimed the badge
        vm.expectRevert(AgenTera.NoBadge.selector);
        pass.checkIn();
    }

    function test_MetadataAndInterfaces() public {
        vm.prank(alice);
        pass.claimBadge();
        assertTrue(pass.supportsInterface(0x80ac58cd), "ERC-721 interface");
        assertTrue(pass.supportsInterface(0x01ffc9a7), "ERC-165 interface");
        bytes memory uri = bytes(pass.tokenURI(1));
        assertTrue(uri.length > 50, "tokenURI must be non-trivial");
        vm.expectRevert(AgenTera.NonexistentToken.selector);
        pass.ownerOf(999);
    }

    function test_ConstructorZeroAddressReverts() public {
        vm.expectRevert(AgenTera.ZeroAddress.selector);
        new AgenTera(address(0));
    }

    function test_HoldsAgentIDView() public {
        assertTrue(pass.holdsAgentID(alice), "alice holds Agent ID");
        assertTrue(!pass.holdsAgentID(bob), "bob holds none");
    }
}
