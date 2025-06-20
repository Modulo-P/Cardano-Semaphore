use cardano/assets.{Value, PolicyId, policies, without_lovelace} as assets
use aiken/interval.{ Interval }


// Helper functions

pub fn is_policy_on_value(value: Value, policy_id: PolicyId) -> Bool {
    let result: List<PolicyId> = without_lovelace(value) |> policies()
    result == [policy_id]
}


pub fn is_interval_within(iv1: Interval<Int>,time_pair: (Int,Int)) -> Bool {
    interval.is_entirely_after(iv1, time_pair.1st) && interval.is_entirely_before(iv1, time_pair.2nd) 
}
