//use aiken/builtin.{bytearray_to_integer}
use aiken/collection/dict as dict
use aiken/collection/list
use aiken/crypto as crypto
use aiken/crypto/bls12_381/scalar as scalar
use aiken/merkle_patricia_forestry.{MerklePatriciaForestry} as mpf
use ak_381/groth16.{SnarkVerificationKey, groth_verify} as groth16
use cardano/address.{Script}
use cardano/assets.{PolicyId} as assets
use cardano/transaction.{
  InlineDatum, Input, OutputReference, Transaction, find_input,
}
use group.{GroupDatum}
use utilities.{is_policy_on_value}

pub const null_hash =
  #"0000000000000000000000000000000000000000000000000000000000000000"

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

validator semaphore(oref: OutputReference) {
  mint(rdm: SemaphoreRedeemer, policy_id: PolicyId, self: Transaction) {
    when rdm is {
      Create -> {
        let Transaction { inputs, reference_inputs, outputs, mint, .. } = self

        //let Transaction { inputs, outputs, mint, validity_range,.. } = self
        // Condition 0: Is expected UTxO spent?
        expect Some(_nft_utxo) = find_input(inputs, oref)
        // Condition 1: Is only one Semaphore NFT minted?
        expect [Pair(_asset_name, amount)] =
          mint
            |> assets.tokens(policy_id)
            |> dict.to_pairs()
        let is_one_token_minted: Bool = amount == 1

        // Condition 2: Is Semaphore NFT sent to script?
        let own_script_credential = Script(policy_id)
        expect [output_to_script] =
          list.filter(
            outputs,
            fn(o) { o.address.payment_credential == own_script_credential },
          )
        let is_nft_sent_to_script: Bool =
          is_policy_on_value(output_to_script.value, policy_id)

        // Condition 3: Is there a Semaphore Datum atttached?
        expect InlineDatum(out_datum) = output_to_script.datum
        expect out_semaphore_dat: SemaphoreDatum = out_datum

        // Condition 4: Is group merkle root correctly set?
        expect [group_reference_input] =
          list.filter(
            reference_inputs,
            fn(i) {
              is_policy_on_value(
                i.output.value,
                out_semaphore_dat.group_token_policy,
              )
            },
          )
        expect InlineDatum(group_datum) = group_reference_input.output.datum
        expect group_datum_data: GroupDatum = group_datum
        let is_merkle_root_correct: Bool =
          group_datum_data.group_merke_root == out_semaphore_dat.group_merke_root

        // Condition 5: Is initial MPF root empty?
        let is_nullifier_root_empty: Bool =
          out_semaphore_dat.nullifier_mpf_root == null_hash

        and {
          is_one_token_minted,
          is_nullifier_root_empty,
          is_nft_sent_to_script,
          is_merkle_root_correct,
        }
      }

      _ -> False
    }
  }

  spend(
    datum: Option<SemaphoreDatum>,
    rdm: SemaphoreRedeemer,
    utxo: OutputReference,
    self: Transaction,
  ) {
    when rdm is {
      Signal(zk_proof, mpf_proof, nullifier, signal_hash, signal_message) -> {
        let Transaction { inputs, outputs, .. } = self
        expect Some(dat) = datum

        // Find script input
        expect Some(this_script_input) = find_input(inputs, utxo)
        // Find output sent back to script
        let this_script_address = this_script_input.output.address
        expect [output_to_script] =
          list.filter(outputs, fn(o) { o.address == this_script_address })
        // Condition 0: Is script value sent back?
        let is_value_returned: Bool =
          assets.without_lovelace(output_to_script.value) == assets.without_lovelace(
            this_script_input.output.value,
          )

        // Condition 1: Is Datum preserved?
        expect InlineDatum(out_data) = output_to_script.datum
        expect out_datum: SemaphoreDatum = out_data
        let is_datum_preserved: Bool = and {
            dat.group_merke_root == out_datum.group_merke_root,
            dat.group_token_policy == out_datum.group_token_policy,
            dat.vkey_ref_input == out_datum.vkey_ref_input,
          }

        // Condition 2: Is Snark Verification Keys reference input correct?
        expect Some(snark_vkey_ref_input) =
          find_input(inputs, dat.vkey_ref_input)
        expect InlineDatum(snark_vkey_input) = snark_vkey_ref_input.output.datum
        expect snark_vkey: SnarkVerificationKey = snark_vkey_input

        // Get external nullifier value (The scripthash/policyID of the validator itself)
        expect Script(script_hash) = this_script_address.payment_credential
        expect Some(external_nullifier) =
          scalar.from_bytearray_big_endian(script_hash)


        // Cond 3: Verify ZK proof
        let public_values: List<Int> =
          [
            dat.group_merke_root,
            nullifier,
            signal_hash,
            scalar.to_int(external_nullifier),
          ]
        // External_nullifier
        let is_snark_correct: Bool =
          groth_verify(snark_vkey, zk_proof, public_values)

        // Cond 4: Is the Nullifier already inserted.
        let nullifier_mpf: MerklePatriciaForestry =
          mpf.from_root(dat.nullifier_mpf_root)

        // TODO: The idea is to deserialize the mpf_proof 
        // - Redefine the mpf of the Signal(..) redeemer to bytearray.
        // - Deserealise the mpf_proof to a MPF proof.
        // Look https://github.com/aiken-lang/merkle-patricia-forestry/tree/main/off-chain#prooftocbor-buffer
        expect Some(n_value) = scalar.new(nullifier)
        let nullifier_value: ByteArray =
          scalar.to_bytearray_little_endian(n_value, 0)
        let nullifier_key: ByteArray = crypto.blake2b_256(nullifier_value)
        let new_mpf_nullifier: MerklePatriciaForestry =
          mpf.insert(nullifier_mpf, nullifier_key, nullifier_value, mpf_proof)

        let is_new_nullifier_root: Bool =
          mpf.from_root(out_datum.nullifier_mpf_root) == new_mpf_nullifier

        // Condition 5. Is message tampered?
        // Warning: This imply changing the circuit
        let message_digest = crypto.blake2b_256(signal_message)
        expect Some(message_digest_scalar) = scalar.from_bytearray_big_endian(message_digest)
        let message_digest_int = scalar.to_int(message_digest_scalar)
        let is_signal_message_tampered: Bool =
          message_digest_int == signal_hash
        and {
          is_value_returned,
          is_datum_preserved,
          is_snark_correct,
          is_new_nullifier_root,
          is_signal_message_tampered,
        }
      }

      _ -> False
    }
  }

  else(_) {
    fail
  }
}