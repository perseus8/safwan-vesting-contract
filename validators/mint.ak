use aiken/transaction.{Redeemer, ScriptContext}

validator {
  fn mint_test_token(_redeemer: Redeemer, _ctx: ScriptContext) -> Bool {
    True
  }
}
