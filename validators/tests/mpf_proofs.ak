use aiken/crypto
use aiken/merkle_patricia_forestry.{MerklePatriciaForestry} as mpf
use aiken/crypto/bls12_381/scalar
use semaphore.{null_hash}



test insert_nullifier() fail {
    
    let nullifier_mpf: MerklePatriciaForestry = mpf.from_root(null_hash)
    expect Some(nullifier) = scalar.new(38625149408878199693830158794989919308150121977174408046140837150457929803892)
    let nullifier_value: ByteArray =
          scalar.to_bytearray_little_endian(nullifier, 0)
    let nullifier_key: ByteArray = crypto.blake2b_256(nullifier_value)
    let new_mpf_nullifier: MerklePatriciaForestry =
          mpf.insert(nullifier_mpf, nullifier_key, nullifier_value, [])
    new_mpf_nullifier == mpf.from_root(null_hash)

}

          

