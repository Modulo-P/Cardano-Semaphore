use aiken/builtin.{sha2_256}
use aiken/bytearray.{concat}
use aiken/list.{at}
use aiken/math
use aiken/string

pub type MerkleTreeData {
  root: ByteArray,
  depth: Int,
  size: Int,
  last_subtree: List<ByteArray>,
}

fn empty_tree() -> MerkleTreeData {
  MerkleTreeData { root: #"", depth: 0, size: 0, last_subtree: [] }
}

fn build_tree(tree: MerkleTreeData, size: Int) -> (MerkleTreeData, Int) {
  if size > 0 {
    let tree =
      insert(
        tree,
        #"fc686c314491e1f68bf1899fc54b2327353c44dd1ab4ed56538ef623edd1e866",
      )
    build_tree(tree, size - 1)
  } else {
    (tree, 0)
  }
}

fn big_tree() -> MerkleTreeData {
  MerkleTreeData {
    root: #"",
    depth: 20,
    size: 1048576,
    last_subtree: [
      #"42", #"fc686c314491e1f68bf1899fc54b2327353c44dd1ab4ed56538ef623edd1e866",
      #"9d325199a924c092825aef78d8cdadce0c9dff13519a102931a6e7eb9dcb64b5",
      #"8c97e9721f4c9890e86049143f7c18598ead24e4f439fd4a9f6cb475bfe3d718",
      #"678ecabba5d0b60af2d68c79ecdf9e0e846f865d5d9e14bd38c957c2cc344912",
      #"71dc4fc7417a1e551dde68e80d97fb22b95f913162dffeff322bfe4a4abfed32",
      #"9ceea49a59158de4fd9818568231d481997f71582f23fff35d3e5ae31d238ff9",
      #"2c498ed46dbc8fe5b2a28a1042e24950774109b2fe682210d1bd60de5e13d47f",
      #"736b24b70bbcaa8da8f50d50cae6bbeeac824357802648cb6697f7cf49d79117",
      #"a2070c5472f5bd086fd38c725a7b50d5bc1e761ccd826b52c454f338765c221d",
      #"bafaf1f9f1df1b431c780de10cc000737322fc72ba0356512d356692c5c5e016",
      #"118f5a02ffc81a85abf344d4fe01f3bcdae5f09e29a5b8c84ac89ef7123a725e",
      #"e22e78c44dd840a22dfeaf454fe11d8ca14fdaccf576461da82f2d25ddd8c717",
      #"2c4ec78a6de742364c68f23352bef52b9de077170292cc1d604bf2bbf8669691",
      #"2e8ffe9678535875cc7f25e2ea212dad53b94e9f09c136b2ce9c845de516f7ec",
      #"e06f3d1a50ee318d74bce51c6f0caf181f54d60c3025900997cba0264b2a260a",
      #"6391dc77150567fd63f37a02d3befd5e75e18cff8573a90fa245f455574ea18c",
      #"f25b833a759143b61102b4a42b2e3f556f4ea7f21bb08854a6556a8cac4c80fc",
      #"5e99bd38d86e7958a75c886b1c84b0159ee25da5abe435f3f33860c3d985b234",
      #"2b864368a5ff7ea355ad7501fce3007ff443b61965fcc9621bbea5ee59e80bad",
      #"54e565a119ce1a43b0667436aa4b27223f2460c6cbcea0ce799f9b2a735a8154",
    ],
  }
}

fn calculate_last_subtree(
  last_subtree: List<ByteArray>,
  level: Int,
  node: ByteArray,
  index: Int,
  last_subtree_result: List<ByteArray>,
  depth: Int,
) -> (List<ByteArray>, Int, ByteArray, Int, List<ByteArray>, Int) {
  if level < depth {
    if index % 2 == 1 {
      expect Some(elem) = at(last_subtree, level)
      let new_node = sha2_256(concat(elem, node))
      calculate_last_subtree(
        last_subtree,
        level + 1,
        new_node,
        index / 2,
        list.concat(last_subtree_result, [elem]),
        depth,
      )
    } else {
      calculate_last_subtree(
        last_subtree,
        level + 1,
        node,
        index / 2,
        list.concat(last_subtree_result, [node]),
        depth,
      )
    }
  } else {
    (
      last_subtree,
      level,
      node,
      index,
      list.concat(last_subtree_result, [node]),
      depth,
    )
  }
}

pub fn insert(data: MerkleTreeData, leaf: ByteArray) -> MerkleTreeData {
  let MerkleTreeData { depth, size, last_subtree, .. } = data

  let depth =
    if math.pow2(depth) < size + 1 {
      depth + 1
    } else {
      depth
    }

  let last_subtree =
    calculate_last_subtree(last_subtree, 0, leaf, size, [], depth).5th
  expect Some(root) = list.last(last_subtree)
  MerkleTreeData { root, depth, size: size + 1, last_subtree }
}

fn trace_tree(tree: MerkleTreeData) {
  trace string.concat(@"depth: ", string.from_int(tree.depth))
  trace string.concat(@"size: ", string.from_int(tree.size))
  trace_bytearray_list(tree.last_subtree)
}

fn trace_bytearray_list(list: List<ByteArray>) {
  when list is {
    [x, ..xs] -> {
      trace bytearray.to_hex(x)
      trace_bytearray_list(xs)
    }
    [] -> Void
  }
}

test insert_node() {
  let dummy_tree = empty_tree()
  let new_tree = insert(dummy_tree, #"04")
  dummy_tree.size + 1 == new_tree.size
}

test insert_multiple_nodes() {
  let tree = empty_tree()
  let tree = build_tree(tree, 105).1st
  trace_tree(tree)
  tree.root == #"b54dc8b2c66404d5a6bcc5addb05877fdec3f1740c1190f4f816ed32425eb14a"
}

test insert_multiple_nodes_big_tree() {
  let tree = big_tree()
  let tree = build_tree(tree, 25).1st
  trace_tree(tree)
  tree.root == tree.root
}

// test demo_tree() {
//   let tree = empty_tree()
//   trace @"empty tree"
//   trace_tree(tree)
//   trace @"#############################"
//   trace @"insert 0"
//   let tree = insert(tree, #"42")
//   trace_tree(tree)
//   trace @"#############################"
//   trace @"insert 1"
//   let tree = insert(tree, #"42")
//   trace_tree(tree)
//   trace @"#############################"
//   trace @"insert 2"
//   let tree = insert(tree, #"42")
//   trace_tree(tree)
//   trace @"#############################"
//   trace @"insert 3"
//   let tree = insert(tree, #"42")
//   trace_tree(tree)
//   True
// }

test demo_tree_1000() {
  let tree = empty_tree()
  let tree = build_tree(tree, 1000).1st
  trace_tree(tree)
  tree.root == #"ee970cb045c3549d3778c3498ff61f2c1bdd8fb9d548103ba6d3e663c2be12eb"
}
