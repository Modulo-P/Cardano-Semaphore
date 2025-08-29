use aiken/merkle_patricia_forestry as mpf
use cardano/assets.{PolicyId} as assets
use cardano/transaction.{OutputReference}
use ak_381/groth16

pub type SemaphoreRedeemer {
  Create
  Signal(groth16.Proof, mpf.Proof, Int, Int, ByteArray)
}

pub type SemaphoreDatum {
  group_token_policy: PolicyId,
  group_merke_root: Int,
  nullifier_mpf_root: ByteArray,
  vkey_ref_input: OutputReference,
}