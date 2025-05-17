
#[test_only]
module university::university_tests;
// uncomment this line to import the module
 use university::election;
use sui::test_scenario;

const ENotImplemented: u64 = 0;
const Addresss1: address = @0xa;

#[test]
fun test_create_student_voting_nft() {
    let scenario = test_scenario::begin(Addresss1);
    election::create_student_voting_nft
}

#[test, expected_failure(abort_code = ::university::university_tests::ENotImplemented)]
fun test_university_fail() {
    abort ENotImplemented
}

