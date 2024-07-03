use aiken/hash.{sha3_256}
use aiken/transaction.{OutputReference, ScriptContext, Transaction}
use aiken/value
use ak_381/groth16.{groth_verify, Proof, SnarkVerificationKey}
//use settled_pimt/merke_tree

type Redeemer {
    Create
    Modify
    Signal
}

type SemaphoreDatum {
    group_merke_root: ByteArray,
    tree_depth: Int, 
    admin_pkh: ByteArray,
    nullifier_merkle_root: ByteArray,
    vkey_ref_input: ByteArray,
}

validator(oref: OutputReference) {
    fn mint (rdm: Redeemer, ctx: ScriptContext) -> Bool {
       
        when rdm is {

            Create -> {
                let ScriptContext { transaction, purpose } = ctx 
                let Transaction { inputs, outputs, mint,.. } = transaction

                // Condition 0: Is expected UTxO spent?

                expect Some(nft_utxo) = find_input(inputs, oref) 
                
                // Condition 1: Is only one Group NFT minted?

                expect [(asset_name, amount)] =
                transaction.mint
                    |> value.from_minted_value
                    |> value.tokens(script_policy_id)
                    |> dict.to_list()
                
                let is_one_token_minted: Bool = amount == 1

                // Condition 2: Is Group NFT sent to script?

                expect Mint(script_policy_id) = purpose
                let own_script_credential = ScriptCredential(script_policy_id)

                expect [output_to_script] = list.filter(outputs, fn (o) { o.address.payment_credential == own_script_credential })

                is_one_token_minted

            }

            _ -> False
        }
    }

    fn spend(dat: SemaphoreDatum, rdm: Redeemer, ctx: ScriptContext) -> Bool {
        expect Spend(script_oref) = ctx.purpose

        when rdm is {
            Modify -> {
                let Transaction { inputs, outputs, extra_signatories.. } = ctx.transaction

                // Condition 0: Is Tx signed by admin?

                let is_signed_by_admin: Bool = list.has(transaction.extra_signatories, admin_pkh)

                // Find script address and value

                let this_script_input = find_own_input(script_oref)
                let this_script_address = this_script_input.output.address
                let this_script_value =  this_script_input.output.value |> without_lovelace()
                

                // Condition 1: Is script value sent back?

                expect [output_to_script] = list.filter(outputs, fn (o) { o.address == this_script_address })
                let is_value_returned: Bool = without_lovelace(output_to_script.value) == this_script_value

                and {
                    is_signed_by_admin,
                    is_value_returned,
                }

            }

            Signal -> {
                let Transaction { inputs, outputs, extra_signatories.. } = ctx.transaction                

                // Find script input
                let this_script_input = find_own_input(script_oref)
     
                // Find output sent back to script
                expect [output_to_script] = list.filter(outputs, fn (o) { o.address == this_script_input.output.address })
                
                // Condition 0: Is script value sent back?
                let is_value_returned: Bool = without_lovelace(output_to_script.value) == without_lovelace(this_script_input.value) 

                // Condition 1: Is Datum preserved?
                let in_datum = this_script_input.output.datum
                expect out_datum: SemaphoreDatum = output_to_script.datum
                let is_datum_preserved: Bool = and {
                    in_datum.group_merke_root == out_datum.group_merke_root,
                    in_datum.tree_depth == out_datum.tree_depth,
                    in_datum.admin_pkh == out_datum.admin_pkh,
                    in_datum.vkey_ref_input == out_datum.vkey_ref_input,
                }

                // Condition 2: Is Snark Verification Keys reference input correct?
                expect Some(snark_vkey_input) = find_input(inputs, dat.vkey_ref_input)

                // Cond 3: Verify ZK proof
                let is_snark_correct: Bool = todo

                and {
                    is_value_returned,
                    is_datum_preserved,
                    is_snark_correct,
                }

            }

            _ -> False
        }
    }

}

pub fn find_own_input(oref: OutputReference) -> Input {
  expect Some(input) =
    ctx.transaction.inputs
      |> transaction.find_input(oref)
  input
}