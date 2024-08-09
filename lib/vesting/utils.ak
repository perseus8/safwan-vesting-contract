use aiken/transaction.{Datum, InlineDatum}
use vesting/types.{VestingDatum}

pub fn extract_vesting_datum_from_datum(datum: Datum) -> VestingDatum {
  when datum is {
    InlineDatum(inline_data) -> {
      expect vesting_datum: VestingDatum = inline_data
      vesting_datum
    }
    _ -> fail @"raid datum must be inline"
  }
}
