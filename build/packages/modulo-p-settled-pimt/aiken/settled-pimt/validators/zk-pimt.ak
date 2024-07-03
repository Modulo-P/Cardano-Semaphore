use aiken/transaction.{ScriptContext}
use settled_pimt/merkle_tree.{MerkleTreeData}

type Datum {
  merkle_tree_data: MerkleTreeData,
}

type Action {
  Action
}

type Redeemer {
  action: Action,
}

validator {
  fn zk_pimt(
    _datum: Datum,
    _redeemer: Redeemer,
    _context: ScriptContext,
  ) -> Bool {
    True
  }
}
