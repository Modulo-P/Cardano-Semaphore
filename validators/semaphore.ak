use aiken/builtin.{bytearray_to_integer}
use aiken/collection/dict as dict
use aiken/collection/list
use aiken/interval.{ Interval }
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

                // Condition 3: Is there a Semaphore Datum atttached?
                expect InlineDatum(out_datum) = output_to_script.datum
                expect out_semaphore_dat: SemaphoreDatum = out_datum

                // Condition 4: Is initial MPF root empty?
                let is_nullifier_root_empty: Bool = out_semaphore_dat.nullifier_mpf_root == null_hash

                // Condition 5: Is Event time correctly set?
                //let (event_start, event_end) = out_semaphore_dat.event_date
                // let is_event_time_set: Bool = event_start < event_end && is_entirely_after(validity_range, event_start)

                is_one_token_minted && is_nullifier_root_empty
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

            Signal(zk_proof, mpf_proof, (key, value)) -> {
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
                    dat.tree_depth == out_datum.tree_depth,
                    dat.admin_pkh == out_datum.admin_pkh,
                    dat.vkey_ref_input == out_datum.vkey_ref_input,
                    dat.event_date == out_datum.event_date,
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

                // Condition 5: Is within event time range?
                let is_within_time_event: Bool = is_interval_within(validity_range, dat.event_date)

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


fn is_interval_within(iv1: Interval<Int>,time_pair: (Int,Int)) -> Bool {
    interval.is_entirely_after(iv1, time_pair.1st) && interval.is_entirely_before(iv1, time_pair.2nd) 
}

test iiw_1() {
    let a = interval.between(5,10)
    let tp = (1,20)
    is_interval_within(a,tp)
}

test iiw_2() fail {
    let a = interval.between(5,30)
    let tp = (1,20)
    is_interval_within(a,tp)
}

test iiw_3() {
    let a = interval.between(2,19)
    let tp = (1,20)
    is_interval_within(a,tp)
}

test iiw_4() fail {
    let a = interval.between(21,30)
    let tp = (1,20)
    is_interval_within(a,tp)
}

test iiw_5() fail {
    let a = interval.between(15,30)
    let tp = (1,20)
    is_interval_within(a,tp)
}

test iiw_6() fail {
    let a = interval.between(1,10)
    let tp = (20,60)
    is_interval_within(a,tp)
}

test iiw_7() fail {
    let a = interval.between(1,30)
    let tp = (20,60)
    is_interval_within(a,tp)
}

test iiw_8() {
    let a = interval.between(34,35)
    let tp = (33,60)
    is_interval_within(a,tp)
}

