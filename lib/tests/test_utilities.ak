use cardano/assets.{from_asset, from_lovelace, merge}
use utilities.{is_policy_on_value}

test check_policy_1() {
  let ada = from_lovelace(2000000)
  let token = from_asset(#"ab", #"cd", 1)
  let val = merge(token, ada)
  is_policy_on_value(val, #"ab") == True
}

test check_policy_2() {
  let ada = from_lovelace(2000000)
  let token = from_asset(#"df", #"cd", 2)
  let val = merge(token, ada)
  is_policy_on_value(val, #"df") == True
}

test check_policy_3() {
  let token_1 = from_asset(#"ab", #"cd", 1)
  let token_2 = from_asset(#"df", #"cd", 1)
  let val = merge(token_1, token_2)
  is_policy_on_value(val, #"ab") == True
}

test check_policy_4() {
  let ada = from_lovelace(2000000)
  let token_1 = from_asset(#"ab", #"cd", 1)
  let token_2 = from_asset(#"df", #"cd", 1)
  let val = merge(token_1, token_2) |> merge(ada)
  is_policy_on_value(val, #"ab")
}

test check_policy_5() {
  let ada = from_lovelace(2000000)
  let token_1 = from_asset(#"ab", #"cd", 1)
  let token_2 = from_asset(#"df", #"cd", 1)
  let token_3 = from_asset(#"ed", #"cd", 1)
  let val = merge(token_1, token_2) |> merge(ada) |> merge(token_3)
  is_policy_on_value(val, #"ed")
}

test check_policy_6() fail {
  let ada = from_lovelace(2000000)
  let token_1 = from_asset(#"ab", #"cd", 1)
  let token_2 = from_asset(#"df", #"cd", 1)
  let token_3 = from_asset(#"ed", #"cd", 1)
  let val = merge(token_1, token_2) |> merge(ada) |> merge(token_3)
  is_policy_on_value(val, #"ff")
}

test check_policy_7() fail {
  let token_1 = from_asset(#"ab", #"cd", 1)
  let token_2 = from_asset(#"df", #"cd", 1)
  let val = merge(token_1, token_2)
  is_policy_on_value(val, #"ff")
}

test check_policy_8() fail {
  let ada = from_lovelace(2000000)
  let token = from_asset(#"ab", #"cd", 1)
  let val = merge(token, ada)
  is_policy_on_value(val, #"ff")
}
