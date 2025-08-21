use aiken/collection/list as list
use cardano/assets.{PolicyId, Value, policies} as assets

// Helper functions

pub fn is_policy_on_value(value: Value, policy_id: PolicyId) -> Bool {
  let result: List<PolicyId> = policies(value)
  list.has(result, policy_id)
}
