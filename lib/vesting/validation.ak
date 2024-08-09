use aiken/cbor.{diagnostic}
use aiken/dict
use aiken/interval.{Finite}
use aiken/list
use aiken/string
use aiken/transaction.{Output, Transaction, ValidityRange, find_script_outputs}
use aiken/transaction/credential.{ScriptCredential}
use aiken/transaction/value.{PolicyId}
use common/types.{ScriptHash, VerificationKeyHash} as c_types
use common/utils.{inputs_by_payment_credential, trace_if_false} as c_utils
use vesting/types.{VestingDatum}
use vesting/utils.{extract_vesting_datum_from_datum}

pub fn can_spend(
  tx: Transaction,
  script_hash: ScriptHash,
  admin_pub_key_hash: VerificationKeyHash,
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
) -> Bool {
  let Output(_, o_value, o_datum, _) = output
  let o_raid_datum = extract_vesting_datum_from_datum(o_datum)
  let check_datum =
    o_raid_datum == VestingDatum(start_time, duration, intervals, total_amount)

  //   let raid_locked =
  //     when value.tokens(o_value, raid_policy_id) |> dict.to_pairs is {
  //       [_] -> True
  //       _ -> False
  //     }
  let spent_value = total_amount - value.lovelace_of(o_value)
  let available_value_per = total_amount / intervals
  let lock_expiration_time =
    start_time + duration / intervals * (
      spent_value / available_value_per + 1
    )
  let check_lock =
    when range.lower_bound.bound_type is {
      Finite(tx_earliest_time) -> lock_expiration_time <= tx_earliest_time
      _ -> False
    }

  and {
    trace_if_false(check_datum, @"raid datum must be correct"),
    // trace @"lock expiration time"
    // trace diagnostic(lock_expiration_time)
    // trace @"available_value_per"
    // trace diagnostic(available_value_per)
    // trace @"spent_value"
    // trace diagnostic(spent_value)
    trace_if_false(
      check_lock,
      string.concat(
        @"can lock mroe after unlock time",
        diagnostic(lock_expiration_time),
      ),
    ),
  }
}
