use cardano/assets.{Value, PolicyId, policies} as assets
use aiken/collection/list as list
use aiken/interval.{ Interval }


// Helper functions

pub fn is_policy_on_value(value: Value, policy_id: PolicyId) -> Bool {
    let result: List<PolicyId> = policies(value)
    list.has(result, policy_id)
}


pub fn is_interval_within(iv1: Interval<Int>,time_pair: (Int,Int)) -> Bool {
    interval.is_entirely_after(iv1, time_pair.1st) && interval.is_entirely_before(iv1, time_pair.2nd) 
}
