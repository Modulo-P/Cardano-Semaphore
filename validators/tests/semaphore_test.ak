//use aiken/merkle_patricia_forestry.{MerklePatriciaForestry} as mpf
use aiken/interval.{Interval, IntervalBound, Finite }
use cardano/transaction.{OutputReference, Transaction, Output, NoDatum, InlineDatum, Input, ValidityRange}
use cardano/address.{Script, Address, from_verification_key}
use cardano/assets.{Value, from_asset, from_lovelace}
use semaphore.{Redeemer, Create, Modify, SemaphoreDatum}

 // Params of the minting part of the script
const initial_oref: OutputReference = OutputReference {
        transaction_id: #"c18fb45bb0450c6af07abf0cf8252aef5324a048f86ba9f3dc868bc7",
        output_index: 0,
    }
const rdm: Redeemer = Create
const policy_id: ByteArray = #"c18fb45bb0450c6af07abf0cf8252aef5324a048f86ba9f3dc868bc7"

fn define_create_tx() -> Transaction {

    let tx: Transaction = transaction.placeholder 

    // Define the Tx...

    //  Set expected input needed to create an unique PolicyId needed for the NFT.
    let bootstrap_output = Output {
        address: from_verification_key(#"1234"),
        value: from_lovelace(1),
        datum: NoDatum,
        reference_script: None,
    }
    
    let initial_utxo: Input = Input {
        output_reference: initial_oref,
        output: bootstrap_output,
    }
    let add_input_to_tx: Transaction = Transaction { ..tx, inputs: [initial_utxo] }  


    // Define that the Group NFT has been minted in the Tx.
    let group_token: Value = from_asset(policy_id, #"ab", 1)
    let add_token_to_tx: Transaction = Transaction { ..add_input_to_tx, mint: group_token }  

    // Define an output where the Group NFT is sent back to script
    // Attach Datum to output
    let vkey_oref = OutputReference {
        transaction_id: #"01bc",
        output_index: 0,
    }
    let semaphore_datum: SemaphoreDatum = SemaphoreDatum {
        group_merke_root: #"00",
        tree_depth: 1, 
        admin_pkh: #"aabbcc",
        nullifier_mpf_root: #"0000000000000000000000000000000000000000000000000000000000000000",
        vkey_ref_input: vkey_oref,
        event_date: (20, 30)
    }
    let tx_outputs: List<Output> = [
        Output {
            address: Address { payment_credential: Script(policy_id), stake_credential: None },
            value: group_token,
            datum: InlineDatum(semaphore_datum),
            reference_script: None,
        }
    ]
    let output_to_tx: Transaction = Transaction {..add_token_to_tx, outputs: tx_outputs}

    output_to_tx
}


test create_group_nft() {
    let tx = define_create_tx()
    semaphore.semaphore.mint(initial_oref, rdm, policy_id, tx)
}



fn define_modify_tx() -> Transaction {
    let previous_tx = define_create_tx()

    // Add validity range
    let vr: ValidityRange = Interval
    { lower_bound:
        IntervalBound { bound_type: Finite(1), is_inclusive: True }
    , upper_bound:
        IntervalBound { bound_type: Finite(5), is_inclusive: False }
    }
    let add_validity_range_to_tx = Transaction {..previous_tx, validity_range: vr}

    // Singature
    let add_signature_to_tx = Transaction {..add_validity_range_to_tx, extra_signatories: [#"aabbcc"]}


    // Let the output of the previous Tx be the input
    expect [prev_output] = previous_tx.outputs
    let utxo =  Input {
        output_reference: OutputReference { transaction_id: #"9abc", output_index: 0},
        output: prev_output,
    }
    let add_input_to_tx = Transaction {..add_signature_to_tx, inputs: [utxo]}

    // Modify datum and sent output back to address
    expect InlineDatum(datum) = prev_output.datum
    expect semaphore_datum: SemaphoreDatum = datum
    let modified_datum = SemaphoreDatum {..semaphore_datum, group_merke_root: #"01"}
    let modified_output = Output { ..prev_output, datum: InlineDatum(modified_datum) }
    let add_output_to_tx = Transaction {..add_input_to_tx, outputs: [modified_output]}
    add_output_to_tx
}

test modify_group() {
    let rdm = Modify
    let oref = OutputReference { transaction_id: #"9abc", output_index: 0}
    let prev_tx = define_create_tx()
    expect[prev_output] = prev_tx.outputs
    expect InlineDatum(prev_dat) = prev_output.datum
    expect previous_datum: SemaphoreDatum = prev_dat
    let tx = define_modify_tx()
    semaphore.semaphore.spend(initial_oref,Some(previous_datum), rdm, oref, tx)
}

