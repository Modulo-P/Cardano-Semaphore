use aiken/hash.{blake2b_256}
use aiken/bytearray
//validator(lista: List<ByteArray>) {
//    fn spend
//}

fn how_many_hashes(input: ByteArray, counter: Int) -> ByteArray {
    if counter == 0 {
        input
    } else {
        let to_be_hashed = bytearray.concat(input, input)
        blake2b_256(to_be_hashed) |> how_many_hashes(_, counter - 1)
    }
}

test hashes_256() {
    how_many_hashes(#"0000",257) != #"01"
}