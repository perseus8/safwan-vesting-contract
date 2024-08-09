use aiken/transaction.{ScriptContext, Spend, Transaction}
use common/types.{VerificationKeyHash} as c_types
use common/utils.{get_script_hash}
use vesting/types.{VestingDatum}
use vesting/validation.{can_spend}

validator(admin_pub_key_hash: VerificationKeyHash) {
  fn vesting(datum: VestingDatum, _redeemer: Void, ctx: ScriptContext) {
    let ScriptContext(Transaction { inputs, .. } as tx, purpose) = ctx
    let script_hash = get_script_hash(inputs, purpose)
    when purpose is {
      Spend(_) -> can_spend(tx, script_hash, admin_pub_key_hash, datum)
      _ -> False
    }
  }
}
