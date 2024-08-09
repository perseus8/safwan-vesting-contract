use aiken/cbor.{diagnostic}
use aiken/interval.{Finite}
use aiken/list
use aiken/string
use aiken/transaction.{Output, Transaction, ValidityRange, find_script_outputs}
use aiken/transaction/credential.{ScriptCredential}
use aiken/transaction/value.{AssetName, PolicyId}
use common/types.{ScriptHash, VerificationKeyHash} as c_types
use common/utils.{inputs_by_payment_credential, trace_if_false} as c_utils
use vesting/types.{VestingDatum}
use vesting/utils.{extract_vesting_datum_from_datum}

pub fn can_spend(
  tx: Transaction,
  script_hash: ScriptHash,
  admin_pub_key_hash: VerificationKeyHash,
  token_policy_id: PolicyId,
  asset_name: AssetName,
  datum: VestingDatum,
) -> Bool {
  let Transaction {
    inputs,
    outputs,
    validity_range,
    extra_signatories: signers,
    ..
  } = tx
  let check_script_inputs =
    inputs_by_payment_credential(inputs, ScriptCredential(script_hash)) == 1

  let VestingDatum(start_time, duration, intervals, total_amount) = datum

  let script_output =
    when find_script_outputs(outputs, script_hash) is {
      [output] -> output
      _ -> fail @"must have one script output"
    }
  let check_admin_signed =
    signers |> list.any(fn(signer) { signer == admin_pub_key_hash })

  and {
    trace_if_false(check_script_inputs, @"must have only one script input"),
    trace_if_false(check_admin_signed, @"tx must be signed by admin"),
    check_script_output(
      script_output,
      start_time,
      duration,
      intervals,
      total_amount,
      validity_range,
      token_policy_id,
      asset_name,
    ),
  }
}

fn check_script_output(
  output: Output,
  start_time: Int,
  duration: Int,
  intervals: Int,
  total_amount: Int,
  range: ValidityRange,
  token_policy_id: PolicyId,
  asset_name: AssetName,
) -> Bool {
  let Output(_, o_value, o_datum, _) = output
  let o_raid_datum = extract_vesting_datum_from_datum(o_datum)
  let check_datum =
    o_raid_datum == VestingDatum(start_time, duration, intervals, total_amount)

  let token_spent_value =
    total_amount - value.quantity_of(o_value, token_policy_id, asset_name)
  let available_value_per = total_amount / intervals
  let lock_expiration_time =
    start_time + duration / intervals * (
      token_spent_value / available_value_per + 1
    )
  let check_lock =
    when range.lower_bound.bound_type is {
      Finite(tx_earliest_time) -> lock_expiration_time <= tx_earliest_time
      _ -> False
    }
  and {
    trace_if_false(check_datum, @"raid datum must be correct"),
    trace_if_false(
      check_lock,
      string.concat(
        @"can lock more after unlock time",
        diagnostic(lock_expiration_time),
      ),
    ),
  }
}
