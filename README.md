# AgentPass

**The on-chain operator badge for verified Agent ID holders — claim once, prove you are a real agent operator, forever.**

AgentPass is a free, soulbound (non-transferable) ERC-721 badge on BNB Chain. Only an address that holds an **Agent ID** can claim it: the contract verifies ownership on-chain against the official Agent ID contract before minting — no server, no manual review, no trust required. A built-in daily check-in lets active agent operators build a public activity streak, turning the badge into a lightweight reputation layer for agent-operated wallets.

Built for the **Binance Wallet × BNB Chain Agent ID Hackathon** (submission period 18 Nov – 9 Dec 2026).

## How Agent ID is used

Agent ID is the core access-control mechanism of AgentPass:

- The official Agent ID contract on BNB Chain is `0x60b9262456de011f7d15a54cdd8c48baaa8b022f` (SPACE ID Agent ID, ERC-721, non-transferable).
- `claimBadge()` calls `balanceOf(msg.sender)` on that contract and reverts unless the result is greater than 0.
- `checkIn()` is restricted to badge holders, one check-in per address per day, with a consecutive-day streak counter.

## Contract

`src/AgentPass.sol` — a single, dependency-free Solidity 0.8.24 contract.

| Function | Behaviour |
|---|---|
| `claimBadge()` | Verifies Agent ID ownership on-chain; mints one soulbound badge per address. Free. |
| `checkIn()` | Badge holders only; once per day; builds/resets a streak. |
| `hasBadge(address)` | Whether an address holds the badge. |
| `holdsAgentID(address)` | Whether an address holds an Agent ID (per the official contract). |
| `totalClaimers()` | Number of badges claimed. |

### Owner permissions — disclosed

**There is no owner and there are no admin functions.** The contract cannot mint outside `claimBadge`, cannot pause, cannot charge fees, cannot hold or withdraw user funds, and its Agent ID contract address is immutable. Badge transfers and approvals always revert (soulbound).

## Tests

Foundry test suite in `test/AgentPass.t.sol` (11 tests: claim gating, double-claim, soulbound reverts, check-in streaks, metadata, interfaces).

```bash
forge build
forge test
```

## Deployment

- Network: BNB Chain (BSC mainnet, chainId 56)
- Constructor argument: the Agent ID contract `0x60b9262456de011f7d15a54cdd8c48baaa8b022f`
- Deployed address: *(added after deployment; source verified on BscScan)*

## Operators

AgentPass is operated by the team behind three Agent IDs that run autonomously on BNB Chain under strict safety gates (contract verification, gas prechecks, explicit user confirmation before any asset movement):

- tiezu.ai — `0x601deb76808b5ed0b07FbD4d57ae6B04bAE6552A`
- satoshii.ai — `0xc29E26ee254252Ac1090D9FaB5BeB5bB8Bd42b7e`
- alexandro.ai — `0xe87365d4e81a36A3373b59D940528148945010ab`

## License

MIT
