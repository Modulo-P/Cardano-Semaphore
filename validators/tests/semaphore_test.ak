//use aiken/collection/dict
use aiken/primitive/bytearray
use cardano/address.{Address, Script, from_verification_key}
use cardano/assets.{from_lovelace, from_asset, add, Value}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}
//use aiken/crypto/bls12_381/scalar
//use aiken/merkle_patricia_forestry.{MerklePatriciaForestry} as mpf
use ak_381/groth16.{Proof, SnarkVerificationKey, groth_verify} as groth16
use group.{GroupDatum}
use semaphore.{SemaphoreRedeemer, SemaphoreDatum, Create, Signal, null_hash}


const initial_oref: OutputReference =
  OutputReference {
    transaction_id: #"c18fb45bb0450c6af07abf0cf8252aef5324a048f86ba9f3dc868bc7",
    output_index: 0,
  }

const group_policy_id: ByteArray =
  #"90edfed2fa3a42f8f14c300a65d72dd866c16fbff0c36bbb8d0108fe"

const semaphore_policy_id: ByteArray = 
  #"abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"



const vk: SnarkVerificationKey =
  SnarkVerificationKey {
    nPublic: 4,
    vkAlpha: #"8fb7afacff69e16e2e4955f3347848f93371cb52f78807e1c6d00b5b44b8a7f1f40fc21acc6c8217c50bbf664a1673c1",
    vkBeta: #"841b44c7ffe4e332dac1ee440bbf1f38ebfd8f48698f6ac2f0d140418e60290e7192fb9736ba31bcc2b35af5b68fc2cf0a5637aebc732bfa98c9f9749633898abacd78fdf5a024e7e2919fb707bad095c879f0d52b0f4c5d8fa23a608e6b09f1",
    vkGamma: #"93e02b6052719f607dacd3a088274f65596bd0d09920b61ab5da61bbdc7f5049334cf11213945d57e5ac7d055d042b7e024aa2b2f08f0a91260805272dc51051c6e47ad4fa403b02b4510b647ae3d1770bac0326a805bbefd48056c8c121bdb8",
    vkDelta: #"863675b7986ba924103084f1ca5e4508d6866a6596ecdb6ce4805a81962ad0d3d442dae66321593e1965d189c56708c00d8f5ab7732e1da01f55aa0fdd7157b674d085337ffaa953666e8f2f4aa80fca76b190efc7ef33a056a3de05042f937f",
    vkAlphaBeta: [
      #"c03182bd4064844b3c7a1bc0c1790123ab71a7451d103c0f97398cfe70b3499a7aed42acccff57b83c85288187a900490d43b836740ebf96f48db42d48514fb77c12ed64aacbe54296144db5191b483c54cc3a27db83289a0d599bb2836c2eb8",
      #"ce089e74db3a1e0ce964a314156386eb46023d4631537f4c85de35b1f39894d3fbb79be14c282684f566018dfeb63a3200b71dbf1f2ded60836366a6b23b2129baed19fbea5de36f98d1998aa1b241b3e367a0ef85af9d4e6f15c5e122672f08",
    ],
    vkIC: [
      #"918c342256aff81001956b3e611ae0c512e47df3bacc9dc1ab7602145e997316f7d036bf74d1fdb861800d28826dddd6",
      #"a40f7abb5973c32cb540a553021be8e393e87d20b4735f9f6dab587b83bc84d4b0698d6db45abd69c64d346f25857b46",
      #"a4f434dd440ceafb354f9562f8a91b3f2db43b0a3dc7d5eb22888745cd26cb71292249984175690221eb16928cdd7c81",
      #"a942747aeaa591c25b1d0c2acd77d6d0a3a7261859f14918e1991dd756cef946aea8587bb539eb128e87b00153ba22f8",
      #"a580a1bc13faae37e53c6fab37eb134e145d08a64f0292e4063a70a2cf6c9d7ee09809e639bd315b13f9e98d04fa4fde",
    ],
  }


const vkey_input: Input =
  Input {
    output_reference: OutputReference {
      transaction_id: #"01bc",
      output_index: 0,
    },
    output: Output {
      address: Address {
        payment_credential: Script(
          #"0000000000000000000000000000000000000000000000000000000000000000",
        ),
        stake_credential: None,
      },
      value: from_lovelace(1),
      datum: InlineDatum(vk),
      reference_script: None,
    },
  }

// Minting logic test
test mint_create_semaphore_token_1() {
    let tx: Transaction = transaction.placeholder
    let actual_admin_pkh: ByteArray = bytearray.from_string(@"admin_public_key_hash")
    let group_token: Value = from_asset(group_policy_id, bytearray.from_string(@"group_token"), 1)
    let semaphore_token: Value = from_asset(semaphore_policy_id, bytearray.from_string(@"semaphore_token"), 1)
    
    // Define the semaphore policy ID (derived from the validator script hash)

    // Create the input UTxO specified in the validator parameter
    let initial_output =
        Output {
        address: from_verification_key(#"1234"),
        value: from_lovelace(2000000),
        datum: NoDatum,
        reference_script: None,
        }
    let initial_utxo: Input =
        Input { output_reference: initial_oref, output: initial_output }

    // Create group reference input with proper group datum
    let group_datum = GroupDatum {
        group_merke_root: 12345678901234567890,
        admin_pkh: actual_admin_pkh,
    }
    let group_value = add(group_token, #"", #"", 1000000)
    let group_reference_output = Output {
        address: Address {
            payment_credential: Script(group_policy_id),
            stake_credential: None,
        },
        value: group_value,
        datum: InlineDatum(group_datum),
        reference_script: None,
    }
    let group_reference_input = Input {
        output_reference: OutputReference {
            transaction_id: bytearray.from_string(@"group_tx_id"),
            output_index: 0,
        },
        output: group_reference_output,
    }

    // Create Semaphore datum for the output
    let semaphore_datum = SemaphoreDatum {
        group_token_policy: group_policy_id,
        group_merke_root: 12345678901234567890,
        nullifier_mpf_root: null_hash,
        vkey_ref_input: vkey_input.output_reference,
    }

    // Create output sent to script (semaphore validator)
    let out_value = add(semaphore_token, #"", #"", 1000000)
    let output_to_own_script = Output {
        address: Address {
            payment_credential: Script(semaphore_policy_id),
            stake_credential: None,
        },
        value: out_value,
        datum: InlineDatum(semaphore_datum),
        reference_script: None,
    }


    // Create redeemer for minting
    let rdm: SemaphoreRedeemer = Create
    
    // Build the complete transaction
    let final_tx: Transaction =
    Transaction {
      ..tx,
      inputs: [initial_utxo],
      reference_inputs: [group_reference_input],
      outputs: [output_to_own_script],
      mint: semaphore_token,
    }

    // Test the minting validator logic
    semaphore.semaphore.mint(initial_oref, rdm, semaphore_policy_id, final_tx)
}


test mint_wrong_value() fail {
    let tx: Transaction = transaction.placeholder
    let actual_admin_pkh: ByteArray = bytearray.from_string(@"admin_public_key_hash")
    let group_token: Value = from_asset(group_policy_id, bytearray.from_string(@"group_token"), 1)
    let semaphore_token: Value = from_asset(semaphore_policy_id, bytearray.from_string(@"semaphore_token"), 2)
    
    // Define the semaphore policy ID (derived from the validator script hash)

    // Create the input UTxO specified in the validator parameter
    let initial_output =
        Output {
        address: from_verification_key(#"1234"),
        value: from_lovelace(2000000),
        datum: NoDatum,
        reference_script: None,
        }
    let initial_utxo: Input =
        Input { output_reference: initial_oref, output: initial_output }

    // Create group reference input with proper group datum
    let group_datum = GroupDatum {
        group_merke_root: 12345678901234567890,
        admin_pkh: actual_admin_pkh,
    }
    let group_value = add(group_token, #"", #"", 1000000)
    let group_reference_output = Output {
        address: Address {
            payment_credential: Script(group_policy_id),
            stake_credential: None,
        },
        value: group_value,
        datum: InlineDatum(group_datum),
        reference_script: None,
    }
    let group_reference_input = Input {
        output_reference: OutputReference {
            transaction_id: bytearray.from_string(@"group_tx_id"),
            output_index: 0,
        },
        output: group_reference_output,
    }

    // Create Semaphore datum for the output
    let semaphore_datum = SemaphoreDatum {
        group_token_policy: group_policy_id,
        group_merke_root: 12345678901234567890,
        nullifier_mpf_root: null_hash,
        vkey_ref_input: vkey_input.output_reference,
    }

    // Create output sent to script (semaphore validator)
    let out_value = add(semaphore_token, #"", #"", 1000000)
    let output_to_own_script = Output {
        address: Address {
            payment_credential: Script(semaphore_policy_id),
            stake_credential: None,
        },
        value: out_value,
        datum: InlineDatum(semaphore_datum),
        reference_script: None,
    }


    // Create redeemer for minting
    let rdm: SemaphoreRedeemer = Create
    
    // Build the complete transaction
    let final_tx: Transaction =
    Transaction {
      ..tx,
      inputs: [initial_utxo],
      reference_inputs: [group_reference_input],
      outputs: [output_to_own_script],
      mint: semaphore_token,
    }

    // Test the minting validator logic
    semaphore.semaphore.mint(initial_oref, rdm, semaphore_policy_id, final_tx)
}

test mint_wrong_address() fail {
    let tx: Transaction = transaction.placeholder
    let actual_admin_pkh: ByteArray = bytearray.from_string(@"admin_public_key_hash")
    let group_token: Value = from_asset(group_policy_id, bytearray.from_string(@"group_token"), 1)
    let semaphore_token: Value = from_asset(semaphore_policy_id, bytearray.from_string(@"semaphore_token"), 1)
    
    // Define the semaphore policy ID (derived from the validator script hash)

    // Create the input UTxO specified in the validator parameter
    let initial_output =
        Output {
            address: from_verification_key(#"1234"),
            value: from_lovelace(2000000),
            datum: NoDatum,
            reference_script: None,
        }
    let initial_utxo: Input =
        Input { output_reference: initial_oref, output: initial_output }

    // Create group reference input with proper group datum
    let group_datum = GroupDatum {
        group_merke_root: 12345678901234567890,
        admin_pkh: actual_admin_pkh,
    }
    let group_value = add(group_token, #"", #"", 1000000)
    let group_reference_output = Output {
        address: Address {
            payment_credential: Script(group_policy_id),
            stake_credential: None,
        },
        value: group_value,
        datum: InlineDatum(group_datum),
        reference_script: None,
    }
    let group_reference_input = Input {
        output_reference: OutputReference {
            transaction_id: bytearray.from_string(@"group_tx_id"),
            output_index: 0,
        },
        output: group_reference_output,
    }

    // Create Semaphore datum for the output
    let semaphore_datum = SemaphoreDatum {
        group_token_policy: group_policy_id,
        group_merke_root: 12345678901234567890,
        nullifier_mpf_root: null_hash,
        vkey_ref_input: vkey_input.output_reference,
    }

    // Create output sent to script (semaphore validator)
    let out_value = add(semaphore_token, #"", #"", 1000000)
    let wrong_address: Address =
      Address { payment_credential: Script(#"aaaabbbb"), stake_credential: None }
    let output_to_own_script = Output {
        address: wrong_address,
        value: out_value,
        datum: InlineDatum(semaphore_datum),
        reference_script: None,
    }


    // Create redeemer for minting
    let rdm: SemaphoreRedeemer = Create
    
    // Build the complete transaction
    let final_tx: Transaction =
    Transaction {
      ..tx,
      inputs: [initial_utxo],
      reference_inputs: [group_reference_input],
      outputs: [output_to_own_script],
      mint: semaphore_token,
    }

    // Test the minting validator logic
    semaphore.semaphore.mint(initial_oref, rdm, semaphore_policy_id, final_tx)
}

test mint_group_root_tamper() fail {
    let tx: Transaction = transaction.placeholder
    let actual_admin_pkh: ByteArray = bytearray.from_string(@"admin_public_key_hash")
    let group_token: Value = from_asset(group_policy_id, bytearray.from_string(@"group_token"), 1)
    let semaphore_token: Value = from_asset(semaphore_policy_id, bytearray.from_string(@"semaphore_token"), 1)
    
    // Define the semaphore policy ID (derived from the validator script hash)

    // Create the input UTxO specified in the validator parameter
    let initial_output =
        Output {
        address: from_verification_key(#"1234"),
        value: from_lovelace(2000000),
        datum: NoDatum,
        reference_script: None,
        }
    let initial_utxo: Input =
        Input { output_reference: initial_oref, output: initial_output }

    // Create group reference input with proper group datum
    let group_datum = GroupDatum {
        group_merke_root: 12345678901234567890,
        admin_pkh: actual_admin_pkh,
    }
    let group_value = add(group_token, #"", #"", 1000000)
    let group_reference_output = Output {
        address: Address {
            payment_credential: Script(group_policy_id),
            stake_credential: None,
        },
        value: group_value,
        datum: InlineDatum(group_datum),
        reference_script: None,
    }
    let group_reference_input = Input {
        output_reference: OutputReference {
            transaction_id: bytearray.from_string(@"group_tx_id"),
            output_index: 0,
        },
        output: group_reference_output,
    }

    // Create Semaphore datum for the output
    let semaphore_datum = SemaphoreDatum {
        group_token_policy: group_policy_id,
        group_merke_root: 1111111111111111111,
        nullifier_mpf_root: null_hash,
        vkey_ref_input: vkey_input.output_reference,
    }

    // Create output sent to script (semaphore validator)
    let out_value = add(semaphore_token, #"", #"", 1000000)
    let output_to_own_script = Output {
        address: Address {
            payment_credential: Script(semaphore_policy_id),
            stake_credential: None,
        },
        value: out_value,
        datum: InlineDatum(semaphore_datum),
        reference_script: None,
    }


    // Create redeemer for minting
    let rdm: SemaphoreRedeemer = Create
    
    // Build the complete transaction
    let final_tx: Transaction =
    Transaction {
      ..tx,
      inputs: [initial_utxo],
      reference_inputs: [group_reference_input],
      outputs: [output_to_own_script],
      mint: semaphore_token,
    }

    // Test the minting validator logic
    semaphore.semaphore.mint(initial_oref, rdm, semaphore_policy_id, final_tx)
}

test mint_no_datum() fail {
    let tx: Transaction = transaction.placeholder
    let actual_admin_pkh: ByteArray = bytearray.from_string(@"admin_public_key_hash")
    let group_token: Value = from_asset(group_policy_id, bytearray.from_string(@"group_token"), 1)
    let semaphore_token: Value = from_asset(semaphore_policy_id, bytearray.from_string(@"semaphore_token"), 1)
    
    // Define the semaphore policy ID (derived from the validator script hash)

    // Create the input UTxO specified in the validator parameter
    let initial_output =
        Output {
        address: from_verification_key(#"1234"),
        value: from_lovelace(2000000),
        datum: NoDatum,
        reference_script: None,
        }
    let initial_utxo: Input =
        Input { output_reference: initial_oref, output: initial_output }

    // Create group reference input with proper group datum
    let group_datum = GroupDatum {
        group_merke_root: 12345678901234567890,
        admin_pkh: actual_admin_pkh,
    }
    let group_value = add(group_token, #"", #"", 1000000)
    let group_reference_output = Output {
        address: Address {
            payment_credential: Script(group_policy_id),
            stake_credential: None,
        },
        value: group_value,
        datum: InlineDatum(group_datum),
        reference_script: None,
    }
    let group_reference_input = Input {
        output_reference: OutputReference {
            transaction_id: bytearray.from_string(@"group_tx_id"),
            output_index: 0,
        },
        output: group_reference_output,
    }



    // Create output sent to script (semaphore validator)
    let out_value = add(semaphore_token, #"", #"", 1000000)
    let output_to_own_script = Output {
        address: Address {
            payment_credential: Script(semaphore_policy_id),
            stake_credential: None,
        },
        value: out_value,
        datum: NoDatum,
        reference_script: None,
    }


    // Create redeemer for minting
    let rdm: SemaphoreRedeemer = Create
    
    // Build the complete transaction
    let final_tx: Transaction =
    Transaction {
      ..tx,
      inputs: [initial_utxo],
      reference_inputs: [group_reference_input],
      outputs: [output_to_own_script],
      mint: semaphore_token,
    }

    // Test the minting validator logic
    semaphore.semaphore.mint(initial_oref, rdm, semaphore_policy_id, final_tx)
}

// Minting logic test
test mint_mpf_root_wrong_setup() fail {
    let tx: Transaction = transaction.placeholder
    let actual_admin_pkh: ByteArray = bytearray.from_string(@"admin_public_key_hash")
    let group_token: Value = from_asset(group_policy_id, bytearray.from_string(@"group_token"), 1)
    let semaphore_token: Value = from_asset(semaphore_policy_id, bytearray.from_string(@"semaphore_token"), 1)
    
    // Define the semaphore policy ID (derived from the validator script hash)

    // Create the input UTxO specified in the validator parameter
    let initial_output =
        Output {
        address: from_verification_key(#"1234"),
        value: from_lovelace(2000000),
        datum: NoDatum,
        reference_script: None,
        }
    let initial_utxo: Input =
        Input { output_reference: initial_oref, output: initial_output }

    // Create group reference input with proper group datum
    let group_datum = GroupDatum {
        group_merke_root: 12345678901234567890,
        admin_pkh: actual_admin_pkh,
    }
    let group_value = add(group_token, #"", #"", 1000000)
    let group_reference_output = Output {
        address: Address {
            payment_credential: Script(group_policy_id),
            stake_credential: None,
        },
        value: group_value,
        datum: InlineDatum(group_datum),
        reference_script: None,
    }
    let group_reference_input = Input {
        output_reference: OutputReference {
            transaction_id: bytearray.from_string(@"group_tx_id"),
            output_index: 0,
        },
        output: group_reference_output,
    }

    // Create Semaphore datum for the output
    let semaphore_datum = SemaphoreDatum {
        group_token_policy: group_policy_id,
        group_merke_root: 12345678901234567890,
        nullifier_mpf_root: #"111111111111",
        vkey_ref_input: vkey_input.output_reference,
    }

    // Create output sent to script (semaphore validator)
    let out_value = add(semaphore_token, #"", #"", 1000000)
    let output_to_own_script = Output {
        address: Address {
            payment_credential: Script(semaphore_policy_id),
            stake_credential: None,
        },
        value: out_value,
        datum: InlineDatum(semaphore_datum),
        reference_script: None,
    }


    // Create redeemer for minting
    let rdm: SemaphoreRedeemer = Create
    
    // Build the complete transaction
    let final_tx: Transaction =
    Transaction {
      ..tx,
      inputs: [initial_utxo],
      reference_inputs: [group_reference_input],
      outputs: [output_to_own_script],
      mint: semaphore_token,
    }

    // Test the minting validator logic
    semaphore.semaphore.mint(initial_oref, rdm, semaphore_policy_id, final_tx)
}


// Zero-Knowledge Constants


const zk_proof: Proof =
  Proof {
    piA: #"88f1a3db3a777e3909a2416c1eaa1a4753959e25ea8e6d314d83508ecb25644a7a49c84d9e0e48ffbb12f0f3620f348a",
    piB: #"8319df022fb874b81e0def688fe3158125682fa9ec0a010f302774a0ecf9087788b3e377da1316170102583d8db8159213fa7138dbabc34655162951f33c7e8a75e3de9e4f8431950f43a792634b09fcec324849cca3ec964f98a44ec500429b",
    piC: #"98c19d179b2cca1526dd3b2ca64f7284bc66229b0b2a470857882e38dfcecedac22a4849231018aea4c193072e76dadc",
  }


const public_values: List<Int> =
  [
    18042041726936857126340562197634539391760931710461643262434315853825286542627,
    23445013842044814549757189106306795768824425794189026441097293917493308616940,
    25050711957853089676855563252373407134946460892559238457710929576024828641940, 
    26752615589533105314083070294476356144393894068720636123966246677904,
  ]

test snark_1() {
  groth_verify(vk, zk_proof, public_values)
}

// Spending logic test - tests the Signal redeemer functionality
test spend_signal_semaphore_1() {
    let tx: Transaction = transaction.placeholder
    
    // Test data extracted from the constants defined above
    let group_merkle_root = 18042041726936857126340562197634539391760931710461643262434315853825286542627
    let nullifier = 23445013842044814549757189106306795768824425794189026441097293917493308616940
    let signal_hash = 25050711957853089676855563252373407134946460892559238457710929576024828641940
    //let external_nullifier = 26752615589533105314083070294476356144393894068720636123966246677904


    // Create the semaphore UTxO reference that we're spending
    let semaphore_utxo_ref = OutputReference {
        transaction_id: bytearray.from_string(@"semaphore_spend_tx_id"),
        output_index: 0,
    }
    
    // Create the initial semaphore datum (input state)
    let initial_semaphore_datum = SemaphoreDatum {
        group_token_policy: group_policy_id,
        group_merke_root: group_merkle_root,
        nullifier_mpf_root: null_hash,  // Initially empty
        vkey_ref_input: vkey_input.output_reference,
    }   
    let semaphore_token: Value = from_asset(semaphore_policy_id, bytearray.from_string(@"semaphore_token"), 1)
    let semaphore_value = add(semaphore_token, #"", #"", 1000000) 
    let semaphore_input_output = Output {
        address: Address {
            payment_credential: Script(semaphore_policy_id),
            stake_credential: None,
        },
        value: semaphore_value,
        datum: InlineDatum(initial_semaphore_datum),
        reference_script: None,
    }
    let semaphore_input = Input {
        output_reference: semaphore_utxo_ref,
        output: semaphore_input_output,
    }
    
    // Create updated nullifier MPF root (after inserting the nullifier)
//    let initial_mpf: MerklePatriciaForestry = mpf.from_root(null_hash)
//    expect Some(n_value) = scalar.new(nullifier)
//    let nullifier_value: ByteArray = scalar.to_bytearray_little_endian(n_value, 0)
//    let nullifier_key: ByteArray = crypto.blake2b_256(nullifier_value)
    
 //   // Create a dummy MPF proof for testing
 //   let mpf_proof: MpfProof = mpf.empty_proof()
 //   let updated_mpf: MerklePatriciaForestry = mpf.insert(initial_mpf, nullifier_key, nullifier_value, mpf_proof)
 //   let updated_mpf_root: ByteArray = mpf.to_root(updated_mpf)
    
    // Create the output semaphore datum (updated state with new nullifier)
    let output_semaphore_datum = SemaphoreDatum {
        group_token_policy: group_policy_id,
        group_merke_root: group_merkle_root,
        nullifier_mpf_root: #"d024bfbb8a109002b537eb86e7510904e695d1bb5dc8d2c64734eccf369bd590",
        vkey_ref_input: vkey_input.output_reference,
    }
    
    // Create the output semaphore UTxO (returned to script)
    let semaphore_output = Output {
        address: Address {
            payment_credential: Script(semaphore_policy_id),
            stake_credential: None,
        },
        value: semaphore_value,  // Same value returned
        datum: InlineDatum(output_semaphore_datum),
        reference_script: None,
    }
    
    // Create the Signal redeemer with ZK proof and MPF proof
    let mpf_proof = []
    let signal_message = #"9f9f0201ffff"
    let signal_redeemer = Signal(zk_proof, mpf_proof, nullifier, signal_hash, signal_message)
    
    // Build the transaction
    let spend_tx: Transaction = Transaction {
        ..tx,
        inputs: [semaphore_input, vkey_input],  // Include vkey as reference input
        outputs: [semaphore_output],
    }
    
    // Test the spending validator logic
    semaphore.semaphore.spend(
        initial_oref,
        Some(initial_semaphore_datum),
        signal_redeemer, 
        semaphore_utxo_ref,
        spend_tx
    )
}


// Spending logic test - tests the Signal redeemer functionality
test spend_value_not_sent_back() fail {
    let tx: Transaction = transaction.placeholder
    
    // Test data extracted from the constants defined above
    let group_merkle_root = 18042041726936857126340562197634539391760931710461643262434315853825286542627
    let nullifier = 23445013842044814549757189106306795768824425794189026441097293917493308616940
    let signal_hash = 25050711957853089676855563252373407134946460892559238457710929576024828641940
    //let external_nullifier = 26752615589533105314083070294476356144393894068720636123966246677904


    // Create the semaphore UTxO reference that we're spending
    let semaphore_utxo_ref = OutputReference {
        transaction_id: bytearray.from_string(@"semaphore_spend_tx_id"),
        output_index: 0,
    }
    
    // Create the initial semaphore datum (input state)
    let initial_semaphore_datum = SemaphoreDatum {
        group_token_policy: group_policy_id,
        group_merke_root: group_merkle_root,
        nullifier_mpf_root: null_hash,  // Initially empty
        vkey_ref_input: vkey_input.output_reference,
    }   
    let semaphore_token: Value = from_asset(semaphore_policy_id, bytearray.from_string(@"semaphore_token"), 1)
    let semaphore_value = add(semaphore_token, #"", #"", 1000000) 
    let semaphore_input_output = Output {
        address: Address {
            payment_credential: Script(semaphore_policy_id),
            stake_credential: None,
        },
        value: semaphore_value,
        datum: InlineDatum(initial_semaphore_datum),
        reference_script: None,
    }
    let semaphore_input = Input {
        output_reference: semaphore_utxo_ref,
        output: semaphore_input_output,
    }
    
    // Create the output semaphore datum (updated state with new nullifier)
    let output_semaphore_datum = SemaphoreDatum {
        group_token_policy: group_policy_id,
        group_merke_root: group_merkle_root,
        nullifier_mpf_root: #"d024bfbb8a109002b537eb86e7510904e695d1bb5dc8d2c64734eccf369bd590",
        vkey_ref_input: vkey_input.output_reference,
    }
    
    // Create the output semaphore UTxO (returned to script)
    let semaphore_output = Output {
        address: Address {
            payment_credential: Script(bytearray.from_string(@"other_address")),
            stake_credential: None,
        },
        value: semaphore_value,  // Same value returned
        datum: InlineDatum(output_semaphore_datum),
        reference_script: None,
    }
    
    // Create the Signal redeemer with ZK proof and MPF proof
    let mpf_proof = []
    let signal_message = #"9f9f0201ffff"
    let signal_redeemer = Signal(zk_proof, mpf_proof, nullifier, signal_hash, signal_message)
    
    // Build the transaction
    let spend_tx: Transaction = Transaction {
        ..tx,
        inputs: [semaphore_input, vkey_input],  // Include vkey as reference input
        outputs: [semaphore_output],
    }
    
    // Test the spending validator logic
    semaphore.semaphore.spend(
        initial_oref,
        Some(initial_semaphore_datum),
        signal_redeemer, 
        semaphore_utxo_ref,
        spend_tx
    )
}

test spend_datum_not_preserved_1() fail {
    let tx: Transaction = transaction.placeholder
    
    // Test data extracted from the constants defined above
    let group_merkle_root = 18042041726936857126340562197634539391760931710461643262434315853825286542627
    let nullifier = 23445013842044814549757189106306795768824425794189026441097293917493308616940
    let signal_hash = 25050711957853089676855563252373407134946460892559238457710929576024828641940
    //let external_nullifier = 26752615589533105314083070294476356144393894068720636123966246677904


    // Create the semaphore UTxO reference that we're spending
    let semaphore_utxo_ref = OutputReference {
        transaction_id: bytearray.from_string(@"semaphore_spend_tx_id"),
        output_index: 0,
    }
    
    // Create the initial semaphore datum (input state)
    let initial_semaphore_datum = SemaphoreDatum {
        group_token_policy: group_policy_id,
        group_merke_root: group_merkle_root,
        nullifier_mpf_root: null_hash,  // Initially empty
        vkey_ref_input: vkey_input.output_reference,
    }   
    let semaphore_token: Value = from_asset(semaphore_policy_id, bytearray.from_string(@"semaphore_token"), 1)
    let semaphore_value = add(semaphore_token, #"", #"", 1000000) 
    let semaphore_input_output = Output {
        address: Address {
            payment_credential: Script(semaphore_policy_id),
            stake_credential: None,
        },
        value: semaphore_value,
        datum: InlineDatum(initial_semaphore_datum),
        reference_script: None,
    }
    let semaphore_input = Input {
        output_reference: semaphore_utxo_ref,
        output: semaphore_input_output,
    }
    
    // Create the output semaphore datum (updated state with new nullifier)
    let output_semaphore_datum = SemaphoreDatum {
        group_token_policy: group_policy_id,
        group_merke_root: 23445013842044814549757189106306795768824425794189026441097293917493308616940, // Another group root
        nullifier_mpf_root: #"d024bfbb8a109002b537eb86e7510904e695d1bb5dc8d2c64734eccf369bd590",
        vkey_ref_input: vkey_input.output_reference,
    }
    
    // Create the output semaphore UTxO (returned to script)
    let semaphore_output = Output {
        address: Address {
            payment_credential: Script(semaphore_policy_id),
            stake_credential: None,
        },
        value: semaphore_value,  // Same value returned
        datum: InlineDatum(output_semaphore_datum),
        reference_script: None,
    }
    
    // Create the Signal redeemer with ZK proof and MPF proof
    let mpf_proof = []
    let signal_message = #"9f9f0201ffff"
    let signal_redeemer = Signal(zk_proof, mpf_proof, nullifier, signal_hash, signal_message)
    
    // Build the transaction
    let spend_tx: Transaction = Transaction {
        ..tx,
        inputs: [semaphore_input, vkey_input],  // Include vkey as reference input
        outputs: [semaphore_output],
    }
    
    // Test the spending validator logic
    semaphore.semaphore.spend(
        initial_oref,
        Some(initial_semaphore_datum),
        signal_redeemer, 
        semaphore_utxo_ref,
        spend_tx
    )
}

test spend_datum_not_preserved_2() fail {
    let tx: Transaction = transaction.placeholder
    
    // Test data extracted from the constants defined above
    let group_merkle_root = 18042041726936857126340562197634539391760931710461643262434315853825286542627
    let nullifier = 23445013842044814549757189106306795768824425794189026441097293917493308616940
    let signal_hash = 25050711957853089676855563252373407134946460892559238457710929576024828641940
    //let external_nullifier = 26752615589533105314083070294476356144393894068720636123966246677904


    // Create the semaphore UTxO reference that we're spending
    let semaphore_utxo_ref = OutputReference {
        transaction_id: bytearray.from_string(@"semaphore_spend_tx_id"),
        output_index: 0,
    }
    
    // Create the initial semaphore datum (input state)
    let initial_semaphore_datum = SemaphoreDatum {
        group_token_policy: group_policy_id,
        group_merke_root: group_merkle_root,
        nullifier_mpf_root: null_hash,  // Initially empty
        vkey_ref_input: vkey_input.output_reference,
    }   
    let semaphore_token: Value = from_asset(semaphore_policy_id, bytearray.from_string(@"semaphore_token"), 1)
    let semaphore_value = add(semaphore_token, #"", #"", 1000000) 
    let semaphore_input_output = Output {
        address: Address {
            payment_credential: Script(semaphore_policy_id),
            stake_credential: None,
        },
        value: semaphore_value,
        datum: InlineDatum(initial_semaphore_datum),
        reference_script: None,
    }
    let semaphore_input = Input {
        output_reference: semaphore_utxo_ref,
        output: semaphore_input_output,
    }
    
    // Create the output semaphore datum (updated state with new nullifier)
    let output_semaphore_datum = SemaphoreDatum {
        group_token_policy: bytearray.from_string(@"another_group_policy"),
        group_merke_root: group_merkle_root, // Another group root
        nullifier_mpf_root: #"d024bfbb8a109002b537eb86e7510904e695d1bb5dc8d2c64734eccf369bd590",
        vkey_ref_input: vkey_input.output_reference,
    }
    
    // Create the output semaphore UTxO (returned to script)
    let semaphore_output = Output {
        address: Address {
            payment_credential: Script(semaphore_policy_id),
            stake_credential: None,
        },
        value: semaphore_value,  // Same value returned
        datum: InlineDatum(output_semaphore_datum),
        reference_script: None,
    }
    
    // Create the Signal redeemer with ZK proof and MPF proof
    let mpf_proof = []
    let signal_message = #"9f9f0201ffff"
    let signal_redeemer = Signal(zk_proof, mpf_proof, nullifier, signal_hash, signal_message)
    
    // Build the transaction
    let spend_tx: Transaction = Transaction {
        ..tx,
        inputs: [semaphore_input, vkey_input],  // Include vkey as reference input
        outputs: [semaphore_output],
    }
    
    // Test the spending validator logic
    semaphore.semaphore.spend(
        initial_oref,
        Some(initial_semaphore_datum),
        signal_redeemer, 
        semaphore_utxo_ref,
        spend_tx
    )
}

test spend_vkey_field_with_incorrect_value() fail {
    let wrong_vk_input: Input =
    Input {
        output_reference: OutputReference {
        transaction_id: #"01bc",
        output_index: 0,
        },
        output: Output {
        address: Address {
            payment_credential: Script(
            #"0000000000000000000000000000000000000000000000000000000000000000",
            ),
            stake_credential: None,
        },
        value: from_lovelace(1),
        datum: InlineDatum(1),
        reference_script: None,
        },
    }

    let tx: Transaction = transaction.placeholder
    
    // Test data extracted from the constants defined above
    let group_merkle_root = 18042041726936857126340562197634539391760931710461643262434315853825286542627
    let nullifier = 23445013842044814549757189106306795768824425794189026441097293917493308616940
    let signal_hash = 25050711957853089676855563252373407134946460892559238457710929576024828641940
    //let external_nullifier = 26752615589533105314083070294476356144393894068720636123966246677904


    // Create the semaphore UTxO reference that we're spending
    let semaphore_utxo_ref = OutputReference {
        transaction_id: bytearray.from_string(@"semaphore_spend_tx_id"),
        output_index: 0,
    }
    
    // Create the initial semaphore datum (input state)
    let initial_semaphore_datum = SemaphoreDatum {
        group_token_policy: group_policy_id,
        group_merke_root: group_merkle_root,
        nullifier_mpf_root: null_hash,  // Initially empty
        vkey_ref_input: wrong_vk_input.output_reference,
    }   
    let semaphore_token: Value = from_asset(semaphore_policy_id, bytearray.from_string(@"semaphore_token"), 1)
    let semaphore_value = add(semaphore_token, #"", #"", 1000000) 
    let semaphore_input_output = Output {
        address: Address {
            payment_credential: Script(semaphore_policy_id),
            stake_credential: None,
        },
        value: semaphore_value,
        datum: InlineDatum(initial_semaphore_datum),
        reference_script: None,
    }
    let semaphore_input = Input {
        output_reference: semaphore_utxo_ref,
        output: semaphore_input_output,
    }
    
    
    // Create the output semaphore datum (updated state with new nullifier)
    let output_semaphore_datum = SemaphoreDatum {
        group_token_policy: group_policy_id,
        group_merke_root: group_merkle_root,
        nullifier_mpf_root: #"d024bfbb8a109002b537eb86e7510904e695d1bb5dc8d2c64734eccf369bd590",
        vkey_ref_input: vkey_input.output_reference,
    }
    
    // Create the output semaphore UTxO (returned to script)
    let semaphore_output = Output {
        address: Address {
            payment_credential: Script(semaphore_policy_id),
            stake_credential: None,
        },
        value: semaphore_value,  // Same value returned
        datum: InlineDatum(output_semaphore_datum),
        reference_script: None,
    }
    
    // Create the Signal redeemer with ZK proof and MPF proof
    let mpf_proof = []
    let signal_message = #"9f9f0201ffff"
    let signal_redeemer = Signal(zk_proof, mpf_proof, nullifier, signal_hash, signal_message)
    
    // Build the transaction
    let spend_tx: Transaction = Transaction {
        ..tx,
        inputs: [semaphore_input, wrong_vk_input],  // Include vkey as reference input
        outputs: [semaphore_output],
    }
    
    // Test the spending validator logic
    semaphore.semaphore.spend(
        initial_oref,
        Some(initial_semaphore_datum),
        signal_redeemer, 
        semaphore_utxo_ref,
        spend_tx
    )
}

test spend_incorrect_zk_proof() fail {
    let other_zk_proof: Proof = Proof {
      piA: #"98d99a7c03164d509d19c96050c8819bc494b0d37fce028fab4f2f94555567f86dd3c032f0a4333ec697c7f278778c7d",
      piB: #"aace565bacf7a59cb0c3d6213b0d456e24ba203ca970017ef3e7a4ff2a107389923ba3537c9e96da835805a36fdd213714da13d3bf26e944e392f324ef76277c8b74158b102a1d9b1ebc5bd106edd6959366ce1fbe469f0e07a72b21480004c8",
      piC: #"87db3006944e7ed1b1b62fa4fd285b60cc32dac42ec0b19583fa7c51c7ed0f188e1c7e1af295a71f163d2d88862ef41c",
    }


    let tx: Transaction = transaction.placeholder
    
    // Test data extracted from the constants defined above
    let group_merkle_root = 18042041726936857126340562197634539391760931710461643262434315853825286542627
    let nullifier = 23445013842044814549757189106306795768824425794189026441097293917493308616940
    let signal_hash = 25050711957853089676855563252373407134946460892559238457710929576024828641940
    //let external_nullifier = 26752615589533105314083070294476356144393894068720636123966246677904


    // Create the semaphore UTxO reference that we're spending
    let semaphore_utxo_ref = OutputReference {
        transaction_id: bytearray.from_string(@"semaphore_spend_tx_id"),
        output_index: 0,
    }
    
    // Create the initial semaphore datum (input state)
    let initial_semaphore_datum = SemaphoreDatum {
        group_token_policy: group_policy_id,
        group_merke_root: group_merkle_root,
        nullifier_mpf_root: null_hash,  // Initially empty
        vkey_ref_input: vkey_input.output_reference,
    }   
    let semaphore_token: Value = from_asset(semaphore_policy_id, bytearray.from_string(@"semaphore_token"), 1)
    let semaphore_value = add(semaphore_token, #"", #"", 1000000) 
    let semaphore_input_output = Output {
        address: Address {
            payment_credential: Script(semaphore_policy_id),
            stake_credential: None,
        },
        value: semaphore_value,
        datum: InlineDatum(initial_semaphore_datum),
        reference_script: None,
    }
    let semaphore_input = Input {
        output_reference: semaphore_utxo_ref,
        output: semaphore_input_output,
    }
      
    // Create the output semaphore datum (updated state with new nullifier)
    let output_semaphore_datum = SemaphoreDatum {
        group_token_policy: group_policy_id,
        group_merke_root: group_merkle_root,
        nullifier_mpf_root: #"d024bfbb8a109002b537eb86e7510904e695d1bb5dc8d2c64734eccf369bd590",
        vkey_ref_input: vkey_input.output_reference,
    }
    
    // Create the output semaphore UTxO (returned to script)
    let semaphore_output = Output {
        address: Address {
            payment_credential: Script(semaphore_policy_id),
            stake_credential: None,
        },
        value: semaphore_value,  // Same value returned
        datum: InlineDatum(output_semaphore_datum),
        reference_script: None,
    }
    
    // Create the Signal redeemer with ZK proof and MPF proof
    let mpf_proof = []
    let signal_message = #"9f9f0201ffff"
    let signal_redeemer = Signal(other_zk_proof, mpf_proof, nullifier, signal_hash, signal_message)
    
    // Build the transaction
    let spend_tx: Transaction = Transaction {
        ..tx,
        inputs: [semaphore_input, vkey_input],  // Include vkey as reference input
        outputs: [semaphore_output],
    }
    
    // Test the spending validator logic
    semaphore.semaphore.spend(
        initial_oref,
        Some(initial_semaphore_datum),
        signal_redeemer, 
        semaphore_utxo_ref,
        spend_tx
    )
}

test spend_nullifier_already_inserted() fail {
    let tx: Transaction = transaction.placeholder
    
    // Test data extracted from the constants defined above
    let group_merkle_root = 18042041726936857126340562197634539391760931710461643262434315853825286542627
    let nullifier = 23445013842044814549757189106306795768824425794189026441097293917493308616940
    let signal_hash = 25050711957853089676855563252373407134946460892559238457710929576024828641940
    //let external_nullifier = 26752615589533105314083070294476356144393894068720636123966246677904


    // Create the semaphore UTxO reference that we're spending
    let semaphore_utxo_ref = OutputReference {
        transaction_id: bytearray.from_string(@"semaphore_spend_tx_id"),
        output_index: 0,
    }
    
    // Create the initial semaphore datum (input state)
    let initial_semaphore_datum = SemaphoreDatum {
        group_token_policy: group_policy_id,
        group_merke_root: group_merkle_root,
        nullifier_mpf_root:  #"d024bfbb8a109002b537eb86e7510904e695d1bb5dc8d2c64734eccf369bd590",  // Initially empty
        vkey_ref_input: vkey_input.output_reference,
    }   
    let semaphore_token: Value = from_asset(semaphore_policy_id, bytearray.from_string(@"semaphore_token"), 1)
    let semaphore_value = add(semaphore_token, #"", #"", 1000000) 
    let semaphore_input_output = Output {
        address: Address {
            payment_credential: Script(semaphore_policy_id),
            stake_credential: None,
        },
        value: semaphore_value,
        datum: InlineDatum(initial_semaphore_datum),
        reference_script: None,
    }
    let semaphore_input = Input {
        output_reference: semaphore_utxo_ref,
        output: semaphore_input_output,
    }
    
    // Create updated nullifier MPF root (after inserting the nullifier)
//    let initial_mpf: MerklePatriciaForestry = mpf.from_root(null_hash)
//    expect Some(n_value) = scalar.new(nullifier)
//    let nullifier_value: ByteArray = scalar.to_bytearray_little_endian(n_value, 0)
//    let nullifier_key: ByteArray = crypto.blake2b_256(nullifier_value)
    
 //   // Create a dummy MPF proof for testing
 //   let mpf_proof: MpfProof = mpf.empty_proof()
 //   let updated_mpf: MerklePatriciaForestry = mpf.insert(initial_mpf, nullifier_key, nullifier_value, mpf_proof)
 //   let updated_mpf_root: ByteArray = mpf.to_root(updated_mpf)
    
    // Create the output semaphore datum (updated state with new nullifier)
    let output_semaphore_datum = SemaphoreDatum {
        group_token_policy: group_policy_id,
        group_merke_root: group_merkle_root,
        nullifier_mpf_root: #"d024bfbb8a109002b537eb86e7510904e695d1bb5dc8d2c64734eccf369bd590",
        vkey_ref_input: vkey_input.output_reference,
    }
    
    // Create the output semaphore UTxO (returned to script)
    let semaphore_output = Output {
        address: Address {
            payment_credential: Script(semaphore_policy_id),
            stake_credential: None,
        },
        value: semaphore_value,  // Same value returned
        datum: InlineDatum(output_semaphore_datum),
        reference_script: None,
    }
    
    // Create the Signal redeemer with ZK proof and MPF proof
    let mpf_proof = []
    let signal_message = #"9f9f0201ffff"
    let signal_redeemer = Signal(zk_proof, mpf_proof, nullifier, signal_hash, signal_message)
    
    // Build the transaction
    let spend_tx: Transaction = Transaction {
        ..tx,
        inputs: [semaphore_input, vkey_input],  // Include vkey as reference input
        outputs: [semaphore_output],
    }
    
    // Test the spending validator logic
    semaphore.semaphore.spend(
        initial_oref,
        Some(initial_semaphore_datum),
        signal_redeemer, 
        semaphore_utxo_ref,
        spend_tx
    )
}


test spend_tampered_message() fail {
    let tx: Transaction = transaction.placeholder
    
    // Test data extracted from the constants defined above
    let group_merkle_root = 18042041726936857126340562197634539391760931710461643262434315853825286542627
    let nullifier = 23445013842044814549757189106306795768824425794189026441097293917493308616940
    let signal_hash = 25050711957853089676855563252373407134946460892559238457710929576024828641940
    //let external_nullifier = 26752615589533105314083070294476356144393894068720636123966246677904


    // Create the semaphore UTxO reference that we're spending
    let semaphore_utxo_ref = OutputReference {
        transaction_id: bytearray.from_string(@"semaphore_spend_tx_id"),
        output_index: 0,
    }
    
    // Create the initial semaphore datum (input state)
    let initial_semaphore_datum = SemaphoreDatum {
        group_token_policy: group_policy_id,
        group_merke_root: group_merkle_root,
        nullifier_mpf_root: null_hash,  // Initially empty
        vkey_ref_input: vkey_input.output_reference,
    }   
    let semaphore_token: Value = from_asset(semaphore_policy_id, bytearray.from_string(@"semaphore_token"), 1)
    let semaphore_value = add(semaphore_token, #"", #"", 1000000) 
    let semaphore_input_output = Output {
        address: Address {
            payment_credential: Script(semaphore_policy_id),
            stake_credential: None,
        },
        value: semaphore_value,
        datum: InlineDatum(initial_semaphore_datum),
        reference_script: None,
    }
    let semaphore_input = Input {
        output_reference: semaphore_utxo_ref,
        output: semaphore_input_output,
    }
    
    // Create updated nullifier MPF root (after inserting the nullifier)
//    let initial_mpf: MerklePatriciaForestry = mpf.from_root(null_hash)
//    expect Some(n_value) = scalar.new(nullifier)
//    let nullifier_value: ByteArray = scalar.to_bytearray_little_endian(n_value, 0)
//    let nullifier_key: ByteArray = crypto.blake2b_256(nullifier_value)
    
 //   // Create a dummy MPF proof for testing
 //   let mpf_proof: MpfProof = mpf.empty_proof()
 //   let updated_mpf: MerklePatriciaForestry = mpf.insert(initial_mpf, nullifier_key, nullifier_value, mpf_proof)
 //   let updated_mpf_root: ByteArray = mpf.to_root(updated_mpf)
    
    // Create the output semaphore datum (updated state with new nullifier)
    let output_semaphore_datum = SemaphoreDatum {
        group_token_policy: group_policy_id,
        group_merke_root: group_merkle_root,
        nullifier_mpf_root: #"d024bfbb8a109002b537eb86e7510904e695d1bb5dc8d2c64734eccf369bd590",
        vkey_ref_input: vkey_input.output_reference,
    }
    
    // Create the output semaphore UTxO (returned to script)
    let semaphore_output = Output {
        address: Address {
            payment_credential: Script(semaphore_policy_id),
            stake_credential: None,
        },
        value: semaphore_value,  // Same value returned
        datum: InlineDatum(output_semaphore_datum),
        reference_script: None,
    }
    
    // Create the Signal redeemer with ZK proof and MPF proof
    let mpf_proof = []
    let tampered_message = #"aabbccdd"
    let signal_redeemer = Signal(zk_proof, mpf_proof, nullifier, signal_hash, tampered_message)
    
    // Build the transaction
    let spend_tx: Transaction = Transaction {
        ..tx,
        inputs: [semaphore_input, vkey_input],  // Include vkey as reference input
        outputs: [semaphore_output],
    }
    
    // Test the spending validator logic
    semaphore.semaphore.spend(
        initial_oref,
        Some(initial_semaphore_datum),
        signal_redeemer, 
        semaphore_utxo_ref,
        spend_tx
    )
}




