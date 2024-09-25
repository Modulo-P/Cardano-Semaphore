use cardano/transaction.{OutputReference, Transaction, Output, NoDatum, Input}
use cardano/address.{Script, Address, from_verification_key}
use cardano/assets.{Value, from_asset, from_lovelace}
use semaphore.{Redeemer, Create}

test create_group_nft() {

    // Params of the script
    let initial_oref: OutputReference = OutputReference {
        transaction_id: #"c18fb45bb0450c6af07abf0cf8252aef5324a048f86ba9f3dc868bc7",
        output_index: 0,
    }
    let rdm: Redeemer = Create
    let policy_id: ByteArray = #"c18fb45bb0450c6af07abf0cf8252aef5324a048f86ba9f3dc868bc7"
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
    let tx_outputs: List<Output> = [
        Output {
            address: Address { payment_credential: Script(policy_id), stake_credential: None },
            value: group_token,
            datum: NoDatum,
            reference_script: None,
        }
    ]
    let output_to_tx: Transaction = Transaction {..add_token_to_tx, outputs: tx_outputs}

    // from_asset(policy_id: PolicyId, asset_name: AssetName, quantity: Int) -> Value

    semaphore.semaphore.mint(initial_oref, rdm, policy_id, output_to_tx)
}

