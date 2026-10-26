use cardano/address.{Address, Script, from_verification_key}
use cardano/assets.{Value, from_asset, from_lovelace, merge}
use cardano/transaction.{Input, InlineDatum, NoDatum, Output, OutputReference, Transaction}
use group_types.{GroupDatum, GroupRedeemer, Create, Update}
use group

// Script Parameter
const initial_oref: OutputReference =
  OutputReference {
    transaction_id: #"c18fb45bb0450c6af07abf0cf8252aef5324a048f86ba9f3dc868bc7",
    output_index: 0,
  }

// Script PolicyId
const policy_id: ByteArray =
  #"90edfed2fa3a42f8f14c300a65d72dd866c16fbff0c36bbb8d0108fe"

// Group Tests

// Success Test
test mint_create_group_1() {
  let tx: Transaction = transaction.placeholder

  // Create the input-utxo specified at the parameter.
  let initial_output =
    Output {
      address: from_verification_key(#"1234"),
      value: from_lovelace(2000000),
      datum: NoDatum,
      reference_script: None,
    }
  let initial_utxo: Input =
    Input { output_reference: initial_oref, output: initial_output }

  // Create the minted value (the group NFT)
  let group_token: Value = from_asset(policy_id, #"ab", 1)

  // Create the output with the NFT sent to the script.
  let group_datum: GroupDatum =
    GroupDatum { group_merke_root: 0, admin_pkh: #"0001" }
  let script_address: Address =
    Address { payment_credential: Script(policy_id), stake_credential: None }
  let output_to_own_script: Output =
    Output {
      address: script_address,
      value: group_token,
      datum: InlineDatum(group_datum),
      reference_script: None,
    }

  // Agreggate all transactions values
  let final_tx: Transaction =
    Transaction {
      ..tx,
      inputs: [initial_utxo],
      outputs: [output_to_own_script],
      mint: group_token,
    }

  let rdm: GroupRedeemer = Create
  group.group.mint(initial_oref, rdm, policy_id, final_tx)
}

// Wrong minted value - must fail
test mint_wrong_minted_value() fail {
  let tx: Transaction = transaction.placeholder

  // Create the input-utxo specified at the parameter.
  let initial_output =
    Output {
      address: from_verification_key(#"1234"),
      value: from_lovelace(2000000),
      datum: NoDatum,
      reference_script: None,
    }
  let initial_utxo: Input =
    Input { output_reference: initial_oref, output: initial_output }

  // Create the minted value (the group NFT)
  let group_token: Value = from_asset(policy_id, #"ab", 2)

  // Create the output with the NFT sent to the script.
  let group_datum: GroupDatum =
    GroupDatum { group_merke_root: 0, admin_pkh: #"0001" }
  let script_address: Address =
    Address { payment_credential: Script(policy_id), stake_credential: None }
  let output_to_own_script: Output =
    Output {
      address: script_address,
      value: group_token,
      datum: InlineDatum(group_datum),
      reference_script: None,
    }

  // Agreggate all transactions values
  let final_tx: Transaction =
    Transaction {
      ..tx,
      inputs: [initial_utxo],
      outputs: [output_to_own_script],
      mint: group_token,
    }

  let rdm: GroupRedeemer = Create
  group.group.mint(initial_oref, rdm, policy_id, final_tx)
}

// Two tokens with distinct asset names - must fail
test mint_two_tokens_different_names() fail {
  let tx: Transaction = transaction.placeholder

  let initial_output =
    Output {
      address: from_verification_key(#"1234"),
      value: from_lovelace(2000000),
      datum: NoDatum,
      reference_script: None,
    }
  let initial_utxo: Input =
    Input { output_reference: initial_oref, output: initial_output }

  // Two distinct asset names, each quantity 1 — dict.to_pairs() yields two elements
  let group_token: Value =
    merge(from_asset(policy_id, #"ab", 1), from_asset(policy_id, #"cd", 1))

  let group_datum: GroupDatum =
    GroupDatum { group_merke_root: 0, admin_pkh: #"0001" }
  let script_address: Address =
    Address { payment_credential: Script(policy_id), stake_credential: None }
  let output_to_own_script: Output =
    Output {
      address: script_address,
      value: group_token,
      datum: InlineDatum(group_datum),
      reference_script: None,
    }

  let final_tx: Transaction =
    Transaction {
      ..tx,
      inputs: [initial_utxo],
      outputs: [output_to_own_script],
      mint: group_token,
    }

  let rdm: GroupRedeemer = Create
  group.group.mint(initial_oref, rdm, policy_id, final_tx)
}

// Sent to incorrect script address - Must fail
test mint_sent_to_wrong_address() fail {
  let tx: Transaction = transaction.placeholder

  // Create the input-utxo specified at the parameter.
  let initial_output =
    Output {
      address: from_verification_key(#"1234"),
      value: from_lovelace(2000000),
      datum: NoDatum,
      reference_script: None,
    }
  let initial_utxo: Input =
    Input { output_reference: initial_oref, output: initial_output }

  // Create the minted value (the group NFT)
  let group_token: Value = from_asset(policy_id, #"ab", 1)

  // Create the output with the NFT sent to the script.
  let group_datum: GroupDatum =
    GroupDatum { group_merke_root: 0, admin_pkh: #"0001" }
  let wrong_address: Address =
    Address { payment_credential: Script(#"aaaabbbb"), stake_credential: None }
  let output_to_own_script: Output =
    Output {
      address: wrong_address,
      value: group_token,
      datum: InlineDatum(group_datum),
      reference_script: None,
    }

  // Agreggate all transactions values
  let final_tx: Transaction =
    Transaction {
      ..tx,
      inputs: [initial_utxo],
      outputs: [output_to_own_script],
      mint: group_token,
    }

  let rdm: GroupRedeemer = Create
  group.group.mint(initial_oref, rdm, policy_id, final_tx)
}


// Extra foreign token in script output - must fail
test mint_extra_token_in_output() fail {
  let tx: Transaction = transaction.placeholder

  let initial_output =
    Output {
      address: from_verification_key(#"1234"),
      value: from_lovelace(2000000),
      datum: NoDatum,
      reference_script: None,
    }
  let initial_utxo: Input =
    Input { output_reference: initial_oref, output: initial_output }

  // Only the group NFT is minted — Condition 1 passes
  let group_token: Value = from_asset(policy_id, #"ab", 1)

  // A foreign token under a different policy carried in the output
  let foreign_policy: ByteArray = #"deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
  let foreign_token: Value = from_asset(foreign_policy, #"ff", 1)

  let group_datum: GroupDatum =
    GroupDatum { group_merke_root: 0, admin_pkh: #"0001" }
  let script_address: Address =
    Address { payment_credential: Script(policy_id), stake_credential: None }
  // Output carries both tokens — policies(without_lovelace(value)) == [group_policy, foreign_policy]
  // != [policy_id] → Condition 2 fails
  let output_to_own_script: Output =
    Output {
      address: script_address,
      value: merge(group_token, foreign_token),
      datum: InlineDatum(group_datum),
      reference_script: None,
    }

  let final_tx: Transaction =
    Transaction {
      ..tx,
      inputs: [initial_utxo],
      outputs: [output_to_own_script],
      mint: group_token,
    }

  let rdm: GroupRedeemer = Create
  group.group.mint(initial_oref, rdm, policy_id, final_tx)
}

// Spending Tests

// Successful Update 
test spend_update_group_1() {
  let tx: Transaction = transaction.placeholder

  let script_address: Address =
    Address { payment_credential: Script(policy_id), stake_credential: None }

  let group_token: Value = from_asset(policy_id, #"ab", 1)

  let pkh: ByteArray = #"0001"

  let previous_datum: GroupDatum =
    GroupDatum { group_merke_root: 0, admin_pkh: pkh }

  // Create the input-utxo specified at the parameter.
  let previous_ouput =
    Output {
      address: script_address,
      value: merge(group_token, from_lovelace(2000000)),
      datum: InlineDatum(previous_datum),
      reference_script: None,
    }

  let prev_oref: OutputReference =
    OutputReference {
        transaction_id: #"12345678",
        output_index: 0,
    }
  let previous_utxo: Input =
    Input { output_reference: prev_oref, output: previous_ouput }



  // Create the output that sends again the value to the script with an actualized Datum 
  let new_datum: GroupDatum =
    GroupDatum { group_merke_root: 1, admin_pkh: #"0001" }
  let new_output: Output =
    Output {
      address: script_address,
      value: merge(group_token, from_lovelace(2000000)),
      datum: InlineDatum(new_datum),
      reference_script: None,
    }


  // Agreggate all transactions values
  let final_tx: Transaction =
    Transaction {
      ..tx,
      inputs: [previous_utxo],
      outputs: [new_output],
      extra_signatories: [pkh]
    }

  let rdm: GroupRedeemer = Update
  group.group.spend(initial_oref, Some(previous_datum), rdm, prev_oref, final_tx)
}


// Successful Update 
test spend_malicious_pkh() fail {
  let tx: Transaction = transaction.placeholder

  let script_address: Address =
    Address { payment_credential: Script(policy_id), stake_credential: None }

  let group_token: Value = from_asset(policy_id, #"ab", 1)

  let pkh: ByteArray = #"0001"

  let previous_datum: GroupDatum =
    GroupDatum { group_merke_root: 0, admin_pkh: pkh }

  // Create the input-utxo specified at the parameter.
  let previous_ouput =
    Output {
      address: script_address,
      value: merge(group_token, from_lovelace(2000000)),
      datum: InlineDatum(previous_datum),
      reference_script: None,
    }

  let prev_oref: OutputReference =
    OutputReference {
        transaction_id: #"12345678",
        output_index: 0,
    }
  let previous_utxo: Input =
    Input { output_reference: prev_oref, output: previous_ouput }



  // Create the output that sends again the value to the script with an actualized Datum 
  let new_datum: GroupDatum =
    GroupDatum { group_merke_root: 1, admin_pkh: #"0001" }
  let new_output: Output =
    Output {
      address: script_address,
      value: merge(group_token, from_lovelace(2000000)),
      datum: InlineDatum(new_datum),
      reference_script: None,
    }


  // Agreggate all transactions values
  let final_tx: Transaction =
    Transaction {
      ..tx,
      inputs: [previous_utxo],
      outputs: [new_output],
      extra_signatories: [#"0abc"]
    }

  let rdm: GroupRedeemer = Update
  group.group.spend(initial_oref, Some(previous_datum), rdm, prev_oref, final_tx)
}


test spend_wrong_address() fail {
  let tx: Transaction = transaction.placeholder

  let script_address: Address =
    Address { payment_credential: Script(policy_id), stake_credential: None }

  let group_token: Value = from_asset(policy_id, #"ab", 1)

  let pkh: ByteArray = #"0001"

  let previous_datum: GroupDatum =
    GroupDatum { group_merke_root: 0, admin_pkh: pkh }

  // Create the input-utxo specified at the parameter.
  let previous_ouput =
    Output {
      address: script_address,
      value: merge(group_token, from_lovelace(2000000)),
      datum: InlineDatum(previous_datum),
      reference_script: None,
    }

  let prev_oref: OutputReference =
    OutputReference {
        transaction_id: #"12345678",
        output_index: 0,
    }
  let previous_utxo: Input =
    Input { output_reference: prev_oref, output: previous_ouput }



  // Send the output to a wrong address
  let wrong_address: Address =
    Address { payment_credential: Script(#"aaaabbbb"), stake_credential: None }
  let new_datum: GroupDatum =
    GroupDatum { group_merke_root: 1, admin_pkh: #"0001" }
  let new_output: Output =
    Output {
      address: wrong_address,
      value: merge(group_token, from_lovelace(2000000)),
      datum: InlineDatum(new_datum),
      reference_script: None,
    }


  // Agreggate all transactions values
  let final_tx: Transaction =
    Transaction {
      ..tx,
      inputs: [previous_utxo],
      outputs: [new_output],
      extra_signatories: [pkh]
    }

  let rdm: GroupRedeemer = Update
  group.group.spend(initial_oref, Some(previous_datum), rdm, prev_oref, final_tx)
}

// Value not conserved
test spend_value_not_conserved() fail {
  let tx: Transaction = transaction.placeholder

  let script_address: Address =
    Address { payment_credential: Script(policy_id), stake_credential: None }

  let group_token: Value = from_asset(policy_id, #"ab", 1)

  let pkh: ByteArray = #"0001"

  let previous_datum: GroupDatum =
    GroupDatum { group_merke_root: 0, admin_pkh: pkh }

  // Create the input-utxo specified at the parameter.
  let previous_ouput =
    Output {
      address: script_address,
      value: merge(group_token, from_lovelace(2000000)),
      datum: InlineDatum(previous_datum),
      reference_script: None,
    }

  let prev_oref: OutputReference =
    OutputReference {
        transaction_id: #"12345678",
        output_index: 0,
    }
  let previous_utxo: Input =
    Input { output_reference: prev_oref, output: previous_ouput }



  // Create the output that sends again the value to the script with an actualized Datum 
  let new_datum: GroupDatum =
    GroupDatum { group_merke_root: 1, admin_pkh: #"0001" }
  let new_output: Output =
    Output {
      address: script_address,
      value: from_lovelace(2000000),
      datum: InlineDatum(new_datum),
      reference_script: None,
    }


  // Agreggate all transactions values
  let final_tx: Transaction =
    Transaction {
      ..tx,
      inputs: [previous_utxo],
      outputs: [new_output],
      extra_signatories: [pkh]
    }

  let rdm: GroupRedeemer = Update
  group.group.spend(initial_oref, Some(previous_datum), rdm, prev_oref, final_tx)
}



// G-1: mint rejects when the input UTxO does not match the oref parameter.
// find_input returns None, the expect crashes.
test mint_wrong_oref() fail {
  let tx: Transaction = transaction.placeholder

  let wrong_oref = OutputReference {
      transaction_id: #"dead",
      output_index: 0,
  }
  let wrong_utxo: Input =
    Input {
      output_reference: wrong_oref,
      output: Output {
        address: from_verification_key(#"1234"),
        value: from_lovelace(2000000),
        datum: NoDatum,
        reference_script: None,
      },
    }

  let group_token: Value = from_asset(policy_id, #"ab", 1)
  let group_datum: GroupDatum =
    GroupDatum { group_merke_root: 0, admin_pkh: #"0001" }
  let script_address: Address =
    Address { payment_credential: Script(policy_id), stake_credential: None }
  let output_to_own_script: Output =
    Output {
      address: script_address,
      value: group_token,
      datum: InlineDatum(group_datum),
      reference_script: None,
    }

  let final_tx: Transaction =
    Transaction {
      ..tx,
      inputs: [wrong_utxo],
      outputs: [output_to_own_script],
      mint: group_token,
    }

  group.group.mint(initial_oref, Create, policy_id, final_tx)
}

// G-2: spending with the Create redeemer hits `_ -> False` and is rejected.
test spend_create_redeemer_rejected() fail {
  let tx: Transaction = transaction.placeholder

  let script_address: Address =
    Address { payment_credential: Script(policy_id), stake_credential: None }
  let group_token: Value = from_asset(policy_id, #"ab", 1)
  let pkh: ByteArray = #"0001"

  let previous_datum: GroupDatum =
    GroupDatum { group_merke_root: 0, admin_pkh: pkh }
  let prev_oref: OutputReference =
    OutputReference { transaction_id: #"12345678", output_index: 0 }
  let previous_utxo: Input =
    Input {
      output_reference: prev_oref,
      output: Output {
        address: script_address,
        value: merge(group_token, from_lovelace(2000000)),
        datum: InlineDatum(previous_datum),
        reference_script: None,
      },
    }

  let new_datum: GroupDatum =
    GroupDatum { group_merke_root: 1, admin_pkh: pkh }
  let new_output: Output =
    Output {
      address: script_address,
      value: merge(group_token, from_lovelace(2000000)),
      datum: InlineDatum(new_datum),
      reference_script: None,
    }

  let final_tx: Transaction =
    Transaction {
      ..tx,
      inputs: [previous_utxo],
      outputs: [new_output],
      extra_signatories: [pkh],
    }

  group.group.spend(initial_oref, Some(previous_datum), Create, prev_oref, final_tx)
}
