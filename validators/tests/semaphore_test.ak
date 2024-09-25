use cardano/transaction.{OutputReference}
use semaphore.{Redeemer, Create}

test create_group_nft() fail {
    let initial_oref: OutputReference = OutputReference {
        transaction_id: #"c18fb45bb0450c6af07abf0cf8252aef5324a048f86ba9f3dc868bc7",
        output_index: 0,
    }
    let policy_id = #"c18fb45bb0450c6af07abf0cf8252aef5324a048f86ba9f3dc868bc7"
    let rdm: Redeemer = Create

    semaphore.semaphore.mint(initial_oref, rdm, policy_id, transaction.placeholder)
}

