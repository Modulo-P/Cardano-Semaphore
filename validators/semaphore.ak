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
                let Transaction { outputs, mint, .. } = transaction
                
                // Condition 1: Is only one Group NFT minted?

                expect [(asset_name, amount)] =
                transaction.mint
                    |> value.from_minted_value
                    |> value.tokens(script_policy_id)
                    |> dict.to_list()
                
                let is_one_token_minted: Bool = amount == 1

                // Condition 2. Is asset name correct? 
                


                // Condition 2: Is Group NFT sent to script?

                expect Mint(script_policy_id) = purpose
                let own_script_credential = ScriptCredential(script_policy_id)

                 expect [output_to_script] = list.filter(outputs, fn (o) { o.address.payment_credential == own_script_credential })

                // Condition 3: Is Datum correct?

            }

            _ -> False
        }
    }

    fn spend(dat: SemaphoreDatum, rdm: Redeemer, ctx: ScriptContext) -> Bool {
        when rdm is {
            Modify -> {
                todo
            }

            Signal -> {
                todo
            }

            _ -> False
        }
    }

}