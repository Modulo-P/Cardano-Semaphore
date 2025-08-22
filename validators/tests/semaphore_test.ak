//use aiken/collection/dict
use aiken/primitive/bytearray
use cardano/address.{Address, Script, from_verification_key}
use cardano/assets.{from_lovelace, from_asset, add, Value}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}
use group.{GroupDatum}
use semaphore.{SemaphoreRedeemer, SemaphoreDatum, Create, null_hash}
use ak_381/groth16.{Proof, SnarkVerificationKey, groth_verify} as groth16


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
    piA: #"98d99a7c03164d509d19c96050c8819bc494b0d37fce028fab4f2f94555567f86dd3c032f0a4333ec697c7f278778c7d",
    piB: #"aace565bacf7a59cb0c3d6213b0d456e24ba203ca970017ef3e7a4ff2a107389923ba3537c9e96da835805a36fdd213714da13d3bf26e944e392f324ef76277c8b74158b102a1d9b1ebc5bd106edd6959366ce1fbe469f0e07a72b21480004c8",
    piC: #"87db3006944e7ed1b1b62fa4fd285b60cc32dac42ec0b19583fa7c51c7ed0f188e1c7e1af295a71f163d2d88862ef41c",
  }

const public_values: List<Int> =
  [
    2918619243380075077683114937688957371178715648700203897594795409293125897247,
    18357242067865281585448401029732015934400637534018503292192114001988596022544,
    1, 
    26752615589533105314083070294476356144393894068720636123966246677904,
  ]

test snark_1() {
  groth_verify(vk, zk_proof, public_values)
}



//  test spend_signal_semaphore_1() {
//
//  }







// Param of the minting part of the script
//const initial_oref: OutputReference =
//  OutputReference {
//    transaction_id: #"c18fb45bb0450c6af07abf0cf8252aef5324a048f86ba9f3dc868bc7",
//    output_index: 0,
//  }