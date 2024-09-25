use aiken/builtin.{bytearray_to_integer}
use aiken/collection/dict as dict
use aiken/collection/list
use cardano/address.{Script}
use cardano/assets.{PolicyId} as assets
use cardano/transaction.{OutputReference, Transaction, Input, find_input, InlineDatum}
use ak_381/groth16.{groth_verify, SnarkVerificationKey} as groth16
use aiken/merkle_patricia_forestry.{MerklePatriciaForestry} as mpf

pub const null_hash =
  #"0000000000000000000000000000000000000000000000000000000000000000"

pub type Redeemer {
    Create
    Modify
    Signal(groth16.Proof, mpf.Proof, (ByteArray, ByteArray))
}

pub type SemaphoreDatum {
    group_merke_root: ByteArray,
    tree_depth: Int, 
    admin_pkh: ByteArray,
    nullifier_mpf_root: ByteArray,
    vkey_ref_input: OutputReference,
}

validator semaphore(oref: OutputReference) {
    mint (rdm: Redeemer, policy_id: PolicyId, self: Transaction) -> Bool {
        when rdm is {
            
            Create -> { 
                let Transaction { inputs, outputs, mint,.. } = self

                // Condition 0: Is expected UTxO spent?

                expect Some(_nft_utxo) = find_input(inputs, oref) 
                
                // Condition 1: Is only one Group NFT minted?

                expect [Pair(_asset_name, amount)] =
                    mint
                    |> assets.tokens(policy_id)
                    |> dict.to_pairs()
                
                let is_one_token_minted: Bool = amount == 1

                // Condition 2: Is Group NFT sent to script?

                let own_script_credential = Script(policy_id)

                expect [output_to_script] = list.filter(outputs, fn (o) { o.address.payment_credential == own_script_credential })

                // Condition 3: Is there a Semaphore Datum atttached?
                expect InlineDatum(out_datum) = output_to_script.datum
                expect out_semaphore_dat: SemaphoreDatum = out_datum

                // Condition 4: Is initial MPF root an empty tree
                let is_nullifier_root_empty: Bool = out_semaphore_dat.nullifier_mpf_root == null_hash

                is_one_token_minted && is_nullifier_root_empty

            }

            _ -> False
        }
    }

    spend(datum: Option<SemaphoreDatum>, rdm: Redeemer, utxo: OutputReference, self: Transaction) -> Bool {
        when rdm is {
            Modify -> {
                let Transaction { inputs, outputs, extra_signatories, .. } = self
                expect Some(dat) = datum

                // Condition 0: Is Tx signed by admin?
                let is_signed_by_admin: Bool = list.has(extra_signatories, dat.admin_pkh)

                // Find script address and value

                expect Some(this_script_input) = find_input(inputs, utxo)
                let this_script_address = this_script_input.output.address
                let this_script_value =  this_script_input.output.value |> assets.without_lovelace()
                

                // Condition 1: Is script value sent back?

                expect [output_to_script] = list.filter(outputs, fn (o) { o.address == this_script_address })
                let is_value_returned: Bool = assets.without_lovelace(output_to_script.value) == this_script_value

                // Define which fields of the Semaphore Datum must be preserved.
                // Condition 2..

                // FIX! Add a time or boolean condition that limits the period in which the admin can modify the group.
                // Condition 3...

                and {
                    is_signed_by_admin,
                    is_value_returned,
                }

            }

            Signal(zk_proof, mpf_proof, (key, value)) -> {
                let Transaction { inputs, outputs, .. } = self      
                expect Some(dat) = datum

                // Find script input
                expect Some(this_script_input) = find_input(inputs, utxo)
     
                // Find output sent back to script
                let this_script_address = this_script_input.output.address
                expect [output_to_script] = list.filter(outputs, fn (o) { o.address == this_script_address})
                
                // Condition 0: Is script value sent back?
                let is_value_returned: Bool = assets.without_lovelace(output_to_script.value) == assets.without_lovelace(this_script_input.output.value) 

                // Condition 1: Is Datum preserved?
                expect InlineDatum(out_data) = output_to_script.datum
                expect out_datum: SemaphoreDatum = out_data
                let is_datum_preserved: Bool = and {
                    dat.group_merke_root == out_datum.group_merke_root,
                    dat.tree_depth == out_datum.tree_depth,
                    dat.admin_pkh == out_datum.admin_pkh,
                    dat.vkey_ref_input == out_datum.vkey_ref_input,
                }

                // Condition 2: Is Snark Verification Keys reference input correct?
                expect Some(snark_vkey_ref_input) = find_input(inputs, dat.vkey_ref_input)
                expect InlineDatum(snark_vkey_input) = snark_vkey_ref_input.output.datum
                expect snark_vkey: SnarkVerificationKey = snark_vkey_input

                // Cond 3: Verify ZK proof
                // Check that the public values order and encoding is correct! FIX!
                expect Script(script_hash) = this_script_address.payment_credential
                let public_values: List<Int> = [
                    bytearray_to_integer(True, dat.group_merke_root),
                    bytearray_to_integer(True, value),
                    bytearray_to_integer(True, script_hash),
                ]
                let is_snark_correct: Bool = groth_verify(snark_vkey, zk_proof, public_values)

                // Cond 4: Is the Nullifier already inserted.
                let nullifier_mpf: MerklePatriciaForestry = mpf.from_root(dat.nullifier_mpf_root)
                let new_mpf_nullifier: MerklePatriciaForestry = mpf.insert(nullifier_mpf, key, value, mpf_proof)
                let is_new_nullifier_root: Bool = mpf.from_root(out_datum.nullifier_mpf_root) == new_mpf_nullifier

                and {
                    is_value_returned,
                    is_datum_preserved,
                    is_snark_correct,
                    is_new_nullifier_root,
                }
            }

            _ -> False
        }
    }
}

