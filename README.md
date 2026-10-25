# Cardano-Semaphore

A Zero-Knowledge implementation of the [Semaphore protocol](https://semaphore.pse.dev/) on Cardano, built with [Aiken](https://aiken-lang.org/) smart contracts and Groth16 proofs over BLS12-381.

## Overview

Semaphore is a ZK protocol originally developed for Ethereum by PSE.DEV. It enables anonymous group membership proofs and one-time signaling: a user can prove they belong to a group and broadcast a message without revealing their identity, while the protocol prevents the same identity from signaling twice.

This repository contains the **on-chain validators** (Aiken/Plutus). The off-chain counterpart — Circom circuits, Groth16 proof generation, and a TypeScript SDK — lives in [modp-semaphore-bls12381](https://github.com/Modulo-P/modp-semaphore-bls12381).

## Protocol Concepts

### Identities

A user generates a secret identity locally. The identity produces a public commitment that is registered in a group. Secret values allow the user to construct ZK proofs tied to their identity without exposing it.

### Groups

A group is a Merkle tree of identity commitments. An administrator manages the group root stored on-chain in the `GroupDatum`. Members prove membership by providing a ZK proof that their commitment is a leaf of that tree.

### Signals

A signal is an anonymous message (vote, preference, opinion) accompanied by a ZK proof of group membership. The protocol prevents double-signaling: each identity can signal at most once per group by recording a nullifier in an on-chain Merkle Patricia Forestry (MPF) trie.

## Security Guarantees

1. **Proof of ownership** — signals can only be produced by the holder of the identity secret.
2. **Proof of membership** — signals are rejected unless the identity is a current member of the group.
3. **Double-signal prevention** — the nullifier trie detects and rejects repeated signals from the same identity.

## Architecture

### `validators/group.ak` — Group validator

Manages the Group NFT lifecycle.

- **Mint (`Create`)** — bootstraps a new group: consumes a one-time UTxO, mints exactly one NFT, sends it to the script address with a valid inline `GroupDatum`, and enforces that the output carries no other tokens.
- **Spend (`Update`)** — allows the group administrator to update `GroupDatum` (e.g. rotate the Merkle root). Requires an admin signature and full value conservation.

### `validators/semaphore.ak` — Semaphore validator

Manages the Semaphore NFT and signal processing.

- **Mint (`Create`)** — bootstraps a semaphore instance: consumes a one-time UTxO, mints exactly one NFT, reads the group Merkle root from a Group reference input, and records it in the output `SemaphoreDatum` alongside an empty nullifier trie root.
- **Spend (`Signal`)** — processes an anonymous signal: verifies the Groth16 ZK proof, inserts the nullifier into the MPF trie, checks the updated trie root in the output datum, and validates the signal message integrity.

### Data types

| Type | Location | Purpose |
|---|---|---|
| `GroupDatum` | `lib/group_types.ak` | On-chain group state: Merkle root + admin key |
| `SemaphoreDatum` | `lib/semaphore_types.ak` | On-chain semaphore state: group policy, Merkle root, nullifier trie root, VKey reference |
| `GroupRedeemer` | `lib/group_types.ak` | `Create` \| `Update` |
| `SemaphoreRedeemer` | `lib/semaphore_types.ak` | `Create` \| `Signal(proof, mpf_proof, nullifier, signal_hash, message)` |

## System Architecture

The full system is split across two repositories:

```
modp-semaphore-bls12381 (off-chain)        Cardano-Semaphore (on-chain)
─────────────────────────────────          ────────────────────────────
packages/circuits                          validators/group.ak
  semaphore.circom                           Group NFT mint + update
  tree.circom   ──── Groth16 proof ────▶   validators/semaphore.ak
                                             Semaphore NFT mint
packages/proof                               Signal spend + nullifier
  verification_key.json ──────────▶           (reads vkey as ref input)
  conversion utils

packages/typescript
  identity/   ──── identity commitment ──▶  GroupDatum.group_merke_root
  group/      ──── Merkle proof ──────────▶  SemaphoreRedeemer.Signal
```

**Off-chain flow:**
1. User generates an identity (`packages/typescript/identity`)
2. Admin inserts the commitment into an incremental Poseidon Merkle tree (`packages/typescript/group`)
3. Admin updates `GroupDatum` on-chain with the new Merkle root (Group `Update` spend)
4. User generates a Groth16 ZK proof with the Circom circuit
5. User submits a `Signal` transaction to the Semaphore validator, including the proof and MPF nullifier proof

## Dependencies

| Package | Version | Purpose |
|---|---|---|
| `aiken-lang/stdlib` | `2.1.0` | Standard library |
| `modulo-p/ak-381` | `v0.1.1` | Groth16 verifier over BLS12-381 |
| `aiken-lang/merkle-patricia-forestry` | `v2.1.0` | On-chain nullifier trie |

## Building

```sh
aiken build
```

## Testing

Run all tests:

```sh
aiken check
```

Run tests matching a pattern:

```sh
aiken check -m group_test
```

The test suite covers 40 unit tests across `group_test`, `semaphore_test`, `mpf_proofs`, and `test_utilities`.

## Off-chain SDK

The [modp-semaphore-bls12381](https://github.com/Modulo-P/modp-semaphore-bls12381) repository provides:

| Package | Description |
|---|---|
| `packages/circuits` | Circom circuits (`semaphore.circom`, `tree.circom`) using Poseidon hash over BLS12-381 |
| `packages/proof` | Groth16 verification key and proof artifacts; conversion utilities for the on-chain format |
| `packages/typescript` | TypeScript SDK — identity generation, incremental Merkle tree management, proof construction |

## Trusted Setup Ceremony

The Groth16 circuit requires a Phase 2 trusted setup specific to the `semaphore.circom` circuit. The ceremony was coordinated by **jmagan-24716625** and completed with **20 independent participants**, followed by a public random beacon contribution.

The final zkey is at `keys/semaphore_final.zkey`. The full verification transcript is at `keys/semaphore_jmagan-24716625_final_verification_transcript.txt`.

**Circuit hash**
```
fc05fe32 90faee66 6c48733a 1fb35d55
61d6bb9a 2e2de081 a27accbc 14d69722
e05bdbe4 6055d700 1472e4eb e1877951
b3719fb5 47a419da b41c5b66 99051aa4
```

**Random beacon** (contribution #21)
```
87f2a1f9324c481498566154212b73153d020bcf06deba3f934a2b95bc9c298f
```
Beacon iterations exponent: 10

**Verification result:** `ZKey Ok!`

The setup is secure as long as at least one of the 20 participants discarded their contribution randomness — the standard security assumption for Groth16 MPC ceremonies.

## Roadmap

- [x] Alpha release
- [x] Group reusability
- [ ] Token-based group management
- [ ] Relayer claiming mechanisms
- [ ] 1-token-1-vote feature
- [x] Trusted setup ceremony (20 participants, beacon applied)

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).

You are free to use, study, modify, and distribute this software, provided that any derivative work is also distributed under the same license.
