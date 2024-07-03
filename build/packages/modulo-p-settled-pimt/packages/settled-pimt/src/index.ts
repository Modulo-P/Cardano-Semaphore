import {LeanIMT} from "@zk-kit/imt"; 
import SHA256 from "sha256";

console.log(SHA256("00").toString());

function hash(a: string, b: string) {
    return SHA256(Buffer.from(a + b, "hex")).toString();
}


const tree = new LeanIMT(hash);

console.log(tree.export())

// for (let i =  0; i < 1048576; i++) {
//     const value = "42";
//     tree.insert(value);
// }

// for (let i = 0; i < 1000; i++) {
//     tree.insert("42");
// }

for (let i = 0; i < 1000; i++) {
    tree.insert("42");
}
console.log("Tree");
console.log(tree.export());
console.log("########################")

console.log("Size: ", tree.size);

// @ts-ignore
const nodes = tree._nodes; 
console.log("Depth: ", nodes.length - 1);

for (let i = 0; i < nodes.length; i++) {
    console.log(nodes[i][nodes[i].length - 1]);
}