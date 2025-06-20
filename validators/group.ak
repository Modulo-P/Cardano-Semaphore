use aiken/collection/dict as dict
use aiken/collection/list
use cardano/address.{Script}
use cardano/assets.{PolicyId, policies, without_lovelace} as assets
use cardano/transaction.{OutputReference, Transaction, Input, find_input}

pub type GroupDatum {
    group_merke_root: Int,
    admin_pkh: ByteArray,
}

pub type GroupRedeemer {
    Create
    Update
}

validator group(oref: OutputReference) {
    mint (rdm: GroupRedeemer, policy_id: PolicyId, self: Transaction) -> Bool {

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
                let out_value: List<PolicyId> = without_lovelace(output_to_script.value) |> policies()
                let is_nft_sent_to_script: Bool = out_value == [policy_id]

                and {
                    is_one_token_minted,
                    is_nft_sent_to_script,
                }
            }

            _ -> False
        }
    }

    spend(datum: Option<GroupDatum>, rdm: GroupRedeemer, utxo: OutputReference, self: Transaction) -> Bool {
        
        when rdm is {

            Update -> {
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

                and {
                    is_signed_by_admin,
                    is_value_returned,
                }

            }

            _ -> False
        }

    }
}