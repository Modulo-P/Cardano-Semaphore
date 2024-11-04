use aiken/collection/list.{unique, length, has, map, all}

// The Ballot is tuple where the (Option_index, option_counter), the index must be unique.
type Ballot = List<(Int,Int)> 



//type VotingDatum {
//    options: List<(Int, Int)>
//}
//
//

validator voting() {
    mint(redeemer: MyMintRedeemer, policy_id: PolicyId, self: Transaction) {
        
        // 
        // 


    }



    spend(datum_opt: Option<MyDatum>, redeemer: MyRedeemer, input: OutputReference, self: Transaction) {
        expect Some(datum) = datum_opt

        // Is the group token spent and send back again (parameter)

        // Is minimum ADA sent back to the script

        // 
        
  }
}



fn vote(options: Ballot, index: Int) -> Ballot {
    map(options, fn (o) { 
        if o.1st == index {
             (o.1st, o.2nd + 1) 
        } else { 
            o 
        } 
    })
}

test vote_1() {
    let ballot = [(0,0)]
    vote(ballot, 0) == [(0,1)]
}

test vote_2() {
    let ballot = [(0,0)]
    { vote(ballot, 0) |> vote(_,0) |> vote(_,0) } == [(0,3)]
}

test vote_3() {
    let ballot = [(0,0), (1,0), (2,0)]
    vote(ballot, 2) ==  [(0,0), (1,0), (2,1)]
}

test vote_4() {
    let ballot = [(0,8), (1,7), (2,3)]
    vote(ballot, 1) ==  [(0,8), (1,8), (2,3)]
}

test vote_5() {
    let ballot = [(0,8), (1,7), (2,3), (3,4)]
    vote(ballot, 0) ==  [(0,9), (1,7), (2,3), (3,4)]
}

test vote_6() {
    let ballot = [(0,8), (1,7), (2,3), (3,4)]
    vote(ballot, 3) ==  [(0,8), (1,7), (2,3), (3,5)]
}


// Are ballot options indexs different and its counters set at Zero?
fn is_ballot_well_formed(options: Ballot) -> Bool {
    if options == [] {
        False
    } else {
        and {
            map(options, fn (option) { option.1st }) |> different2(), // Are indexes different?
            all(options, fn(option) { option.2nd == 0 }),             // All options counter set at 0?
        }       
    }
}

test is_ballot_well_formed_1() {
    let ballot = [(0,0)]
    is_ballot_well_formed(ballot)
}

test is_ballot_well_formed_2() fail {
    let ballot = [(0,1)]
    is_ballot_well_formed(ballot)
}


test is_ballot_well_formed_3() {
    let ballot = [(0,0),(1,0)]
    is_ballot_well_formed(ballot)
}

test is_ballot_well_formed_4() fail {
    let ballot = [(0,1),(1,0)]
    is_ballot_well_formed(ballot)
}

test is_ballot_well_formed_5() fail {
    let ballot = [(0,0),(0,0)]
    is_ballot_well_formed(ballot)
}

test is_ballot_well_formed_6() {
    let ballot = [(0,0),(1,0),(2,0)]
    is_ballot_well_formed(ballot)
}

test is_ballot_well_formed_7() fail {
    let ballot = [(0,0),(1,0),(2,1)]
    is_ballot_well_formed(ballot)
}

test is_ballot_well_formed_8() fail {
    let ballot = [(0,0),(1,0),(1,0)]
    is_ballot_well_formed(ballot)
}




fn different(array: List<a>) -> Bool {
    length(unique(array)) == length(array)
}

test different_1() {
    let l = [1,2,3,4,5]
    different(l) == True 
}

test different_2() {
    let l = [2,2,3,3,3]
    different(l) == False
}

test different_3() {
    let l = [2,3]
    different(l) == True
}

test different_4() {
    let l = []
    different(l) == True
}

fn different2(array: List<a>) -> Bool {
    when array is {
        [] -> True
        [_x] -> True
        [x, ..xs] -> {
            if has(xs, x) {
                False
            } else {
                different(xs)
            }
        }
    }
}

test different_5() {
    let l = [1,2,3,4,5]
    different2(l) == True 
}

test different_6() {
    let l = [2,2,3,3,3]
    different2(l) == False
}

test different_7() {
    let l = [2,3]
    different2(l) == True
}

test different_8() {
    let l = []
    different2(l) == True
}
