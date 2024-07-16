use aiken/dict
//use aiken/hash.{sha3_256}
use aiken/list
use aiken/transaction.{OutputReference, ScriptContext, Transaction, Input, find_input, Mint, Spend, InlineDatum}
use aiken/transaction/credential.{ScriptCredential}
use aiken/transaction/value.{without_lovelace}
//use ak_381/groth16.{groth_verify, Proof, SnarkVerificationKey}
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
    vkey_ref_input: OutputReference,
}

validator(oref: OutputReference) {
    fn mint (rdm: Redeemer, ctx: ScriptContext) -> Bool {
        when rdm is {
            
            Create -> {
                let ScriptContext { transaction, purpose } = ctx 
                let Transaction { inputs, outputs, mint,.. } = transaction
                expect Mint(script_policy_id) = purpose

                // Condition 0: Is expected UTxO spent?

                expect Some(_nft_utxo) = find_input(inputs, oref) 
                
                // Condition 1: Is only one Group NFT minted?

                expect [(_asset_name, amount)] =
                    mint
                    |> value.from_minted_value
                    |> value.tokens(script_policy_id)
                    |> dict.to_list()
                
                let is_one_token_minted: Bool = amount == 1

                // Condition 2: Is Group NFT sent to script?

                let own_script_credential = ScriptCredential(script_policy_id)

                expect [_output_to_script] = list.filter(outputs, fn (o) { o.address.payment_credential == own_script_credential })

                is_one_token_minted

            }

            _ -> False
        }
    }

    fn spend(dat: SemaphoreDatum, rdm: Redeemer, ctx: ScriptContext) -> Bool {
    
        when rdm is {
            Modify -> {
                let Transaction { outputs, extra_signatories, .. } = ctx.transaction

                // Condition 0: Is Tx signed by admin?

                let is_signed_by_admin: Bool = list.has(extra_signatories, dat.admin_pkh)

                // Find script address and value

                let this_script_input = find_own_input(ctx)
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
                let Transaction { inputs, outputs, .. } = ctx.transaction                

                // Find script input
                let this_script_input = find_own_input(ctx)
     
                // Find output sent back to script
                expect [output_to_script] = list.filter(outputs, fn (o) { o.address == this_script_input.output.address })
                
                // Condition 0: Is script value sent back?
                let is_value_returned: Bool = without_lovelace(output_to_script.value) == without_lovelace(this_script_input.output.value) 

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
                expect Some(_snark_vkey_input) = find_input(inputs, dat.vkey_ref_input)

                // Cond 3: Verify ZK proof
                let is_snark_correct: Bool = True

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

pub fn find_own_input(ctx: ScriptContext) -> Input {
  expect Spend(output_ref) = ctx.purpose

  expect Some(input) =
    ctx.transaction.inputs
      |> transaction.find_input(output_ref)
  input
}
