//use aiken/merkle_patricia_forestry.{MerklePatriciaForestry} as mpf
use aiken/interval.{Interval, IntervalBound, Finite }
use cardano/transaction.{OutputReference, Transaction, Output, NoDatum, InlineDatum, Input, ValidityRange}
use cardano/address.{Script, Address, from_verification_key}
use cardano/assets.{Value, from_asset, from_lovelace}
use semaphore.{Redeemer, Create, Modify, SemaphoreDatum}
use ak_381/groth16.{SnarkVerificationKey, groth_verify, Proof} as groth16

 // Params of the minting part of the script
const initial_oref: OutputReference = OutputReference {
        transaction_id: #"c18fb45bb0450c6af07abf0cf8252aef5324a048f86ba9f3dc868bc7",
        output_index: 0,
    }
const rdm: Redeemer = Create
const policy_id: ByteArray = #"90edfed2fa3a42f8f14c300a65d72dd866c16fbff0c36bbb8d0108fe"

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


const vk: SnarkVerificationKey = SnarkVerificationKey {
      nPublic: 4,
      vkAlpha: #"ad196dfb25df276691704695b0dc6e0284eaed9637983b27b0d48bd99bc39a407e4e5979f868279bdeeb797d0b303085",
      vkBeta: #"b673475b6c36f2ec0aa2b7a2adf5c068af93d211d2861fe47aa78ba512e13279c99d50132eefa6bb56c9d794fe9e33bc055028b1e574f48b445469a4f6211100bb108b98366a0691b82ba0b6b8d3de3044305090f60472b53a64aa06fccc6026",
      vkGamma: #"93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8",
      vkDelta: #"8bd611c4c000b033cee88dea75b6d8bd3a01b3121a24c54c9145c23de41fa0a13bf5a1ba78fe48949166231bf2606f821376f6faeef77c570039234f1a86e5de089863895d855dfde0cd678973b0e852f4534b8f50f4d8fe7f75bc8832592377",
      vkAlphaBeta: [
        #"d9514cb0ceb88479f53e5bf97ca0568adc7d6f287f6a302b803995b93810c3d61b71ad802143db791f993fcda18a37d603c7d6295031c847d73cafc4b94b44c712b3d32f7f0dc42f85409fcbae7da85bf8644fd56aaa24db1861d75b1ef7b718",
        #"d72cdf192ef5e8c0c2c45ff1d3423bb542af06154c2813868c9757375dce41ee46be79595f2c4371c3755bffea51958112c4e3484e1f0b36253c4b5a947c91dec46f252788799819f8fafd1f9312fec8f312fd164418998346a1e2ff4d4e8106",
      ],
      vkIC: [
        #"ab42eb1899bc9ad8633bcbef53375c367e5eb472c768d572b1a23fadf20dbcdf0cd739488f4aa84af025d71728347304",
        #"b37ba96820014373b17c51c37b9153caff8ce032dcedea491a23cce5dc01ff4ec17545e8bf014bbb260ba85ab23e2c22",
        #"a27764a9b09941db37b7ebcd098c79df9d43a19065626b7b346d47a22fe0f629bf59d540d0e0fcc097df8fe5f0f915b9",
        #"803c463442d4cd5abff958ee0113dedfe2157f413f739d853fe8895e1e76074f13f893925835439503f7a706c6cff316",
        #"8f4e1be244444d85c555b5b5d9d66d759d85cf5d278dea56726f402ccb2085eaa3bac14a64005431aa1bcd6a80ef5f9a",
      ],
}


const pk: Proof = Proof {
      piA: #"af665919d43a8cc9167334f9c55be0675d4772372297934f5d7ff38c19ab03b982d5e61aaf56e99461d713459541761c",
      piB: #"9724db0d75cffd55d0658f5675dd4c4e8a9e0f04d086535f9469438a2456ee3ff4fa9a06bcf8e6ab4725992af6aac41307bd5c8292b61d5a5f51d867021d8238ecd50b4f0ca3643af40a4c63476f87c7ad4d381f174ff12689eabf61030bfbad",
      piC: #"94d46c41055e66796e79a3c0d67cc43877a0a10a28a4b20ab35351a233ac72c0ad4da21e4983ff2449b1f8853af7e910",
    }

const public_values: List<Int> = [
    26593495781683680956254130405702393360799795146227253887984406106246073779265,
    39998154356742573582406410737258136426965420396087690458856183855652868982871,
    1,
    2
  ] 

test snark_1 () {
    groth_verify(vk, pk, public_values)
}

//const vkey_input: Input = Input {
//    output_reference: OutputReference { transaction_id: #"0034", output_index: 0 },
//    output: Output {
//        address: Address { payment_credential: Script(#"0000000000000000000000000000000000000000000000000000000000000000"), stake_credential: None },
//        value: from_lovelace(1),
//        datum: InlineDatum(vk),
//        reference_script: None,
//    }
//}

//fn signal_tx() -> Transaction {
//    let prev_tx = define_modify_tx()
//    
//}

