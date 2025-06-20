//use aiken/builtin.{bytearray_to_integer}
use aiken/collection/dict as dict
use aiken/collection/list
use cardano/address.{Script}
use cardano/assets.{PolicyId} as assets
use cardano/transaction.{OutputReference, Transaction, Input, find_input, InlineDatum}
use aiken/interval
use ak_381/groth16.{groth_verify, SnarkVerificationKey} as groth16
use aiken/merkle_patricia_forestry.{MerklePatriciaForestry} as mpf
use aiken/crypto/bls12_381/scalar as scalar
use aiken/crypto as crypto
use utilities.{is_policy_on_value, is_interval_within}

pub const null_hash =
  #"0000000000000000000000000000000000000000000000000000000000000000"

pub type Redeemer {
    Create
    Modify
    Signal(groth16.Proof, mpf.Proof, Int, Int)
}

pub type SemaphoreDatum {
    //group_token_policy: PolicyId,
    group_merke_root: Int,
    admin_pkh: ByteArray,
    nullifier_mpf_root: ByteArray,
    vkey_ref_input: OutputReference,
    event_date: (Int, Int),     // (PosixTimeStart, PosixTimeEnd)
}

validator semaphore(oref: OutputReference) {
    mint (rdm: Redeemer, policy_id: PolicyId, self: Transaction) -> Bool {
        when rdm is {
            
            Create -> { 
                let Transaction { inputs, outputs, mint,.. } = self
                //let Transaction { inputs, outputs, mint, validity_range,.. } = self

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
                let is_nft_sent_to_script: Bool = is_policy_on_value(output_to_script.value, policy_id)
                
                

                // Condition 3: Is there a Semaphore Datum atttached?
                expect InlineDatum(out_datum) = output_to_script.datum
                expect out_semaphore_dat: SemaphoreDatum = out_datum

                // Condition 4: Is initial MPF root empty?
                let is_nullifier_root_empty: Bool = out_semaphore_dat.nullifier_mpf_root == null_hash

                // Condition 5: Is Event time correctly set?
                //let (event_start, event_end) = out_semaphore_dat.event_date
                // let is_event_time_set: Bool = event_start < event_end && is_entirely_after(validity_range, event_start)

                and {
                    is_one_token_minted,
                    is_nullifier_root_empty,
                    is_nft_sent_to_script,
                }
            }

            _ -> False
        }
    }

    spend(datum: Option<SemaphoreDatum>, rdm: Redeemer, utxo: OutputReference, self: Transaction) -> Bool {
        when rdm is {
            Modify -> {
                let Transaction { inputs, outputs, validity_range, extra_signatories, .. } = self
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
                 expect InlineDatum(out_data) = output_to_script.datum
                expect out_datum: SemaphoreDatum = out_data
                let is_datum_preserved: Bool = and {
                    dat.event_date == out_datum.event_date, // Revalute this
                    dat.nullifier_mpf_root == out_datum.nullifier_mpf_root,
                }

                // Condition 3: Is the modification before the event?
                // The admin can't modify the Datum once the singaling event starts...
                //expect IntervalBound { bound_type: Finite(last_tx_time_point), is_inclusive: _v } = validity_range.upper_bound
                //let is_before_event: Bool = last_tx_time_point < dat.event_date.1st
                let is_before_event: Bool = interval.is_entirely_before(validity_range, dat.event_date.1st)
                

                and {
                    is_signed_by_admin,
                    is_value_returned,
                    is_datum_preserved,
                    is_before_event,
                }

            }

            Signal(zk_proof, mpf_proof, nullifier, signal_hash) -> {
                let Transaction { inputs, outputs, validity_range, .. } = self
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
                    dat.admin_pkh == out_datum.admin_pkh,
                    dat.vkey_ref_input == out_datum.vkey_ref_input,
                    dat.event_date == out_datum.event_date,
                }

                // Condition 2: Is Snark Verification Keys reference input correct?
                expect Some(snark_vkey_ref_input) = find_input(inputs, dat.vkey_ref_input)
                expect InlineDatum(snark_vkey_input) = snark_vkey_ref_input.output.datum
                expect snark_vkey: SnarkVerificationKey = snark_vkey_input

                // Cond 3: Verify ZK proof
                expect Script(script_hash) = this_script_address.payment_credential
                expect Some(external_nullifier) = scalar.from_bytearray_little_endian(script_hash) 
                let public_values: List<Int> = [
                    dat.group_merke_root,                // Group MT root hash
                    nullifier,                           // Nullifier  
                    signal_hash,                         // SignalHash
                    scalar.to_int(external_nullifier),   // External_nullifier
                ]

                let is_snark_correct: Bool = groth_verify(snark_vkey, zk_proof, public_values)

                // Cond 4: Is the Nullifier already inserted.
                let nullifier_mpf: MerklePatriciaForestry = mpf.from_root(dat.nullifier_mpf_root)

                expect Some(n_value) = scalar.new(nullifier)
                let nullifier_value: ByteArray =  scalar.to_bytearray_little_endian(n_value,0)
                let nullifier_key: ByteArray = crypto.blake2b_256(nullifier_value)
                let new_mpf_nullifier: MerklePatriciaForestry = mpf.insert(nullifier_mpf, nullifier_key, nullifier_value, mpf_proof)

                let is_new_nullifier_root: Bool = mpf.from_root(out_datum.nullifier_mpf_root) == new_mpf_nullifier

                // Condition 5: Is within event time range?
                let is_within_time_event: Bool = is_interval_within(validity_range, dat.event_date)

                // TODO: Condition 6. Is message tampered?
                // It is important to check that digest(signal) == signal_hash, so that a relay doesn't tamper the message.
                // But I will add this constraint as part of the voting validator.                 
                
                and {
                    is_value_returned,
                    is_datum_preserved,
                    is_snark_correct,
                    is_new_nullifier_root,
                    is_within_time_event,
                }
            }

            _ -> False
        }
    }
}



