//use aiken/merkle_patricia_forestry.{MerklePatriciaForestry} as mpf
use cardano/transaction.{OutputReference, Transaction, Output, NoDatum, InlineDatum, Input}
use cardano/address.{Script, Address, from_verification_key}
use cardano/assets.{Value, from_asset, from_lovelace}
use semaphore.{Redeemer, Create, SemaphoreDatum}

const initial_oref: OutputReference = OutputReference {
        transaction_id: #"c18fb45bb0450c6af07abf0cf8252aef5324a048f86ba9f3dc868bc7",
        output_index: 0,
    }
const rdm: Redeemer = Create
const policy_id: ByteArray = #"c18fb45bb0450c6af07abf0cf8252aef5324a048f86ba9f3dc868bc7"

fn define_create_tx() -> Transaction {
        // Params of the script
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

//fn define_modify_tx() -> Transaction {
//    let previous_tx = define_create_tx()
//
//}

