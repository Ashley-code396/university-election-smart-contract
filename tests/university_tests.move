#[test_only]
module university::university_tests {
    use university::university::{Self, AdminCap, StudentVoterNFT, Election};
    use sui::test_scenario::{Self as test, next_tx, ctx};
    use std::string::{Self, String};
    
    const ADMIN: address = @0xAD;
    const STUDENT1: address = @0x1;
    #[allow(unused)]
    const STUDENT2: address = @0x2;
    #[allow(unused)]
    const STUDENT3: address = @0x3;

    #[test]
    fun test_init() {
        let mut scenario = test::begin(ADMIN);
        {
            university::init_for_testing(ctx(&mut scenario));
        };
        next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test::take_from_sender<AdminCap>(&scenario);
            test::return_to_sender(&scenario, admin_cap);
        };
        test::end(scenario);
    }

    #[test]
    fun test_create_student_voting_nft() {
        let mut scenario = test::begin(ADMIN);
        {
            university::init_for_testing(ctx(&mut scenario));
        };
        next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test::take_from_sender<AdminCap>(&scenario);
            university::create_student_voting_nft(
                &admin_cap,
                123,
                ctx(&mut scenario)
            );
            test::return_to_sender(&scenario, admin_cap);
        };
        next_tx(&mut scenario, ADMIN);
        {
            let nft = test::take_from_sender<StudentVoterNFT>(&scenario);
            test::return_to_sender(&scenario, nft);
        };
        test::end(scenario);
    }

    #[test]
    fun test_start_election_and_register_voter() {
        let mut scenario = test::begin(ADMIN);
        {
            university::init_for_testing(ctx(&mut scenario));
        };
        next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test::take_from_sender<AdminCap>(&scenario);
            university::start_election(
                &admin_cap,
                1,
                string::utf8(b"Student Government Election"),
                ctx(&mut scenario)
            );
            test::return_to_sender(&scenario, admin_cap);
        };
        next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test::take_from_sender<AdminCap>(&scenario);
            university::create_student_voting_nft(&admin_cap, 123, ctx(&mut scenario));
            test::return_to_sender(&scenario, admin_cap);
        };
        test::end(scenario);
    }

    #[test]
    fun test_register_candidate() {
        let mut scenario = test::begin(ADMIN);
        {
            university::init_for_testing(ctx(&mut scenario));
        };
        next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test::take_from_sender<AdminCap>(&scenario);
            university::start_election(
                &admin_cap,
                1,
                string::utf8(b"Student Government Election"),
                ctx(&mut scenario)
            );
            university::create_student_voting_nft(&admin_cap, 123, ctx(&mut scenario));
            test::return_to_sender(&scenario, admin_cap);
        };
        next_tx(&mut scenario, ADMIN);
        {
            let mut election = test::take_shared<Election>(&scenario);
            let nft = test::take_from_sender<StudentVoterNFT>(&scenario);
            let mut promises = vector::empty<String>();
            vector::push_back(&mut promises, string::utf8(b"Better food"));
            vector::push_back(&mut promises, string::utf8(b"More events"));
            
            university::register_candidate(
                &nft,
                &mut election,
                string::utf8(b"Alice"),
                promises,
                ctx(&mut scenario)
            );
            test::return_to_sender(&scenario, nft);
            test::return_shared(election);
        };
        test::end(scenario);
    }

    #[test]
    fun test_cast_vote() {
        let mut scenario = test::begin(ADMIN);
        {
            university::init_for_testing(ctx(&mut scenario));
        };
        next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test::take_from_sender<AdminCap>(&scenario);
            university::start_election(
                &admin_cap,
                1,
                string::utf8(b"Student Government Election"),
                ctx(&mut scenario)
            );
            university::create_student_voting_nft(&admin_cap, 123, ctx(&mut scenario));
            test::return_to_sender(&scenario, admin_cap);
        };
        next_tx(&mut scenario, ADMIN);
        {
            let mut election = test::take_shared<Election>(&scenario);
            let nft = test::take_from_sender<StudentVoterNFT>(&scenario);
            let mut promises = vector::empty<String>();
            vector::push_back(&mut promises, string::utf8(b"Better food"));
            
            university::register_candidate(
                &nft,
                &mut election,
                string::utf8(b"Alice"),
                promises,
                ctx(&mut scenario)
            );
            test::return_to_sender(&scenario, nft);
            test::return_shared(election);
        };
        // Create StudentVoterNFT for STUDENT1 and transfer it to STUDENT1
        next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test::take_from_sender<AdminCap>(&scenario);
            university::create_student_voting_nft(&admin_cap, 456, ctx(&mut scenario));
            let voter_nft = test::take_from_sender<StudentVoterNFT>(&scenario);
            transfer::public_transfer(voter_nft, STUDENT1);
            test::return_to_sender(&scenario, admin_cap);
        };
        // STUDENT1 uses their StudentVoterNFT to vote
        next_tx(&mut scenario, STUDENT1);
        {
            let mut election = test::take_shared<Election>(&scenario);
            let mut voter_nft = test::take_from_sender<StudentVoterNFT>(&scenario);
            
            // Use the new get_candidate_id function
            let candidate_id = university::get_candidate_id(&election, 0);
            
            university::cast_vote(
                &mut voter_nft,
                &mut election,
                candidate_id,
                ctx(&mut scenario)
            );
            test::return_to_sender(&scenario, voter_nft);
            test::return_shared(election);
        };
        test::end(scenario);
    }

    #[test]
    fun test_tally_votes() {
        let mut scenario = test::begin(ADMIN);
        {
            university::init_for_testing(ctx(&mut scenario));
        };
        next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test::take_from_sender<AdminCap>(&scenario);
            university::start_election(
                &admin_cap,
                1,
                string::utf8(b"Student Government Election"),
                ctx(&mut scenario)
            );
            test::return_to_sender(&scenario, admin_cap);
        };
        next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test::take_from_sender<AdminCap>(&scenario);
            let mut election = test::take_shared<Election>(&scenario);
            university::tally_votes(&admin_cap, &mut election, ctx(&mut scenario));
            test::return_to_sender(&scenario, admin_cap);
            test::return_shared(election);
        };
        test::end(scenario);
    }

    #[test]
    fun test_update_voting_power() {
        let mut scenario = test::begin(ADMIN);
        {
            university::init_for_testing(ctx(&mut scenario));
        };
        next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test::take_from_sender<AdminCap>(&scenario);
            university::create_student_voting_nft(&admin_cap, 123, ctx(&mut scenario));
            test::return_to_sender(&scenario, admin_cap);
        };
        next_tx(&mut scenario, ADMIN);
        {
            let mut nft = test::take_from_sender<StudentVoterNFT>(&scenario);
            // Simulate one year passing (365 * 24 * 60 * 60 seconds)
            let one_year_later = 365 * 24 * 60 * 60;
            university::update_voting_power(&mut nft, one_year_later);
            test::return_to_sender(&scenario, nft);
        };
        test::end(scenario);
    }

    #[test]
    fun test_graduate_student() {
        let mut scenario = test::begin(ADMIN);
        {
            university::init_for_testing(ctx(&mut scenario));
        };
        next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test::take_from_sender<AdminCap>(&scenario);
            university::create_student_voting_nft(&admin_cap, 123, ctx(&mut scenario));
            test::return_to_sender(&scenario, admin_cap);
        };
        next_tx(&mut scenario, ADMIN);
        {
            let mut nft = test::take_from_sender<StudentVoterNFT>(&scenario);
            university::graduate_student(&mut nft);
            test::return_to_sender(&scenario, nft);
        };
        test::end(scenario);
    }

    #[test]
    fun test_reset_voting_status() {
        let mut scenario = test::begin(ADMIN);
        {
            university::init_for_testing(ctx(&mut scenario));
        };
        next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test::take_from_sender<AdminCap>(&scenario);
            university::create_student_voting_nft(&admin_cap, 123, ctx(&mut scenario));
            test::return_to_sender(&scenario, admin_cap);
        };
        next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = test::take_from_sender<AdminCap>(&scenario);
            let mut nft = test::take_from_sender<StudentVoterNFT>(&scenario);
            university::reset_voting_status(&admin_cap, &mut nft);
            test::return_to_sender(&scenario, nft);
            test::return_to_sender(&scenario, admin_cap);
        };
        test::end(scenario);
    }
}