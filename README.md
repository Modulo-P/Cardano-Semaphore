



# Cardano-Semaphore

## Intro

This repository contains the Aiken implementation of the Semaphore protocol, originally developed for Ethereum by the PSE.DEV group. Semaphore is a Zero-Knowledge based protocol that allows users to privately proof their membership to a group and send messages like preferences or votes anonymously. Essentially, the protocol allows you to accomplish three things:

* Create and register an identity within a group.
* Prove that your identity is a member of the group without revealing exactly who.
* Anonymously broadcast an arbitrary string that can represent a preference, vote or opinion.

 The idea of the protocol is to be a base protocol which can extended to address different privacy oriented applications.

## Key protocol concepts

To understand the protocol we have to take in account three important concepts.
### Identities 

A user can represent themselves by creating an identity. This identity contains unique secret values that are generated locally by the user. These values allow them to prove ownership of the identity and to construct proofs and messages tied to this identity. These secret values are important because they prevent impersonating the user by appending unrelated corrupt messages or proofs.

### Groups 

A group is a set of members, where each member has their identity. A group in Semaphore is represented by a Merkle tree that stores the public identity commitment of each member (the leaves). Later a user can construct a proof showing that their identity is part of the group but without specifying who. Currently these groups are managed by administrators but in the future we'll allow users to join and leave groups independently. 

### Signals (messages) 

The signal is a message that contains an arbitrary string representing a preference, vote, or opinion. This message includes proofs that demonstrate the user is a valid member of the group and that the information sent (message and proofs) was created by an identity.

## Vote Application

Our main idea to port the protocol was to adapt it to create a voting dapp. Currently it only features one identity one vote, but in the future we'll we need to support other voting schemes such as one token one vote. The voting smart contract can be found in the `validators`folder. 

## Security guarantees of the protocol

Considering the above the protocol has cryptographic mechanisms that allows to anonymously check:

1. **Proof of ownership:** Verify that the proofs and messages are being created by the owner of an
   identity. 

2. **Proof of membership:** Verify that the proof and messages are being created by a valid member
   of the group. 

3. **Double signaling:** Detect wether a message has been sent previously by an user, this is
   important since avoids to broadcast a signal twice in a way that can be
   malicious to the Dapp.

## Building

```sh
aiken build
```

## Testing

To run all tests, simply do:

```sh
aiken check
```

To run only tests matching the string `foo`, do:

```sh
aiken check -m foo
```

## Future steps

[x] Alpha version release version

[] Group reusability.

[]  Token based group managing.

[] Relayer claiming mechanisms

[] 1 token 1 vote feature.

## Trusted Setup Ceremony

Todo

## Other resources

Todo



