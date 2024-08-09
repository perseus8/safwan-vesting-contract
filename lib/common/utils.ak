use aiken/bytearray
use aiken/cbor.{diagnostic}
use aiken/hash.{blake2b_256}
use aiken/list
use aiken/string
use aiken/transaction.{
  Input, Mint, Output, OutputReference, ScriptPurpose, Spend, TransactionId,
  find_input,
}
use aiken/transaction/credential.{Address, Credential, ScriptCredential}
use aiken/transaction/value.{AssetName, PolicyId}
use common/types.{ScriptHash}

pub fn trace_if_false(predicate: Bool, msg: String) -> Bool {
  if predicate {
    predicate
  } else {
    trace msg
    predicate
  }
}

pub fn get_spending_script_input(
  inputs: List<Input>,
  purpose: ScriptPurpose,
) -> Input {
  when purpose is {
    Spend(output_ref) ->
      when find_input(inputs, output_ref) is {
        Some(input) -> input
        _ -> fail @"couldn't find script input"
      }
    _ -> fail @"must be executed as spending validator"
  }
}

pub fn get_script_hash(
  inputs: List<Input>,
  purpose: ScriptPurpose,
) -> ScriptHash {
  let script_input = get_spending_script_input(inputs, purpose)
  let Input(_, Output(Address(payment_cred, _), ..)) = script_input
  when payment_cred is {
    ScriptCredential(script_hash) -> script_hash
    _ -> fail @"spending utxo is not from script"
  }
}

pub fn inputs_by_payment_credential(
  inputs: List<Input>,
  payment_cred: Credential,
) -> Int {
  inputs
    |> list.count(
        fn(input) {
          let Input(_, Output(Address(p_cred, ..), ..)) = input
          p_cred == payment_cred
        },
      )
}
