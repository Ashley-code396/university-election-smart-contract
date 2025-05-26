
 ///Module: university
module university::university;

// For Move coding conventions, see
// https://docs.sui.io/concepts/sui-move-concepts/conventions



   //==IMPORTS===


    

    use sui::event;
    use std::string::String;
    

    // === ADMIN CAPABILITY ===

    public struct AdminCap has key {
        id: UID,
    }

    /// Called once at module publish to mint the admin capability.
      fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx))
    }

    // === STRUCTS ===

    public struct StudentVoterNFT has key, store {
        id: UID,
        name: vector<u8>,
        description: vector<u8>,
        image_url: vector<u8>,
        student_id: u64,
        voting_power: u64,
        is_graduated: bool,
        last_updated: u64,
        has_voted: bool,
    }

    public struct Candidate has key, store {
        id: UID,
        student_id: u64,
        name: vector<String>,
        campaign_promises: vector<String>,
        vote_count: u64,
    }

    public struct Vote has key, store {
        id: UID,
        voter_id: u64,
        candidate_id: u64,
        voting_power: u64,
    }

    public struct ElectionResult has key, store {
        id: UID,
        candidate_id: u64,
        total_votes: u64,
    }

    // === EVENTS ===

    public struct StudentVoterNFTCreated has copy, drop {
        student_id: u64,
        voting_power: u64,
    }

    public struct VotingPowerUpdated has copy, drop {
        student_id: u64,
        new_voting_power: u64,
    }

    public struct StudentGraduated has copy, drop {
        student_id: u64,
    }

    public struct CandidateRegistered has copy, drop {
        student_id: u64,
        name: vector<String>,
    }

    public struct VoteCast has copy, drop {
        voter_id: u64,
        candidate_id: u64,
        voting_power: u64,
    }

    public struct ElectionResultsTallied has copy, drop {
        candidate_id: u64,
        total_votes: u64,
    }

    // === HELPERS ===

    fun u64_to_vector(value: u64): vector<u8> {
        let mut result: vector<u8> = vector::empty();
        let mut temp = value;
        if (temp == 0) {
            vector::push_back(&mut result, 48); // ASCII '0'
            return result
        };
        while (temp > 0) {
            let digit = (temp % 10) as u8;
            vector::push_back(&mut result, 48 + digit);
            temp = temp / 10;
        };
        // Reverse vector
        let mut reversed: vector<u8> = vector::empty();
        let mut i = vector::length(&result);
        while (i > 0) {
            i = i - 1;
            vector::push_back(&mut reversed, *vector::borrow(&result, i));
        };
        reversed
    }

    // === ENTRY FUNCTIONS ===

    /// ADMIN-ONLY: Mint a new student NFT
    public entry fun create_student_voting_nft(
        admin: &AdminCap,
        student_id: u64,
        ctx: &mut TxContext
    ) {
        let current_epoch = tx_context::epoch(ctx);
        let voter_nft = StudentVoterNFT {
            id: object::new(ctx),
            name: b"University Voter ID",
            description: b"This is a unique voter ID for university elections.",
            image_url: b"https://i.ibb.co/fzq9JmxX/element5-digital-T9-CXBZLUvic-unsplash.jpg",
            student_id,
            voting_power: 1,
            is_graduated: false,
            last_updated: current_epoch,
            has_voted: false,
        };
        transfer::transfer(voter_nft, tx_context::sender(ctx));
        event::emit(StudentVoterNFTCreated { student_id, voting_power: 1 });
    }

    // Update voting power (simulate academic progression, once per year)
    public entry fun update_voting_power(
        voter_nft: &mut StudentVoterNFT,
        current_time: u64
    ) {
        assert!(!voter_nft.is_graduated, 0);
        let time_elapsed = current_time - voter_nft.last_updated;
        if (time_elapsed >= 365 * 24 * 60 * 60 && voter_nft.voting_power < 4) {
            voter_nft.voting_power = voter_nft.voting_power + 1;
            voter_nft.last_updated = current_time;
            // Update description
            let mut new_description = b"Your voting power is now: ";
            let voting_power_str = u64_to_vector(voter_nft.voting_power);
            vector::append(&mut new_description, voting_power_str);
            voter_nft.description = new_description;
            event::emit(VotingPowerUpdated {
                student_id: voter_nft.student_id,
                new_voting_power: voter_nft.voting_power,
            });
        }
    }

    // Graduate student (deactivate NFT)
    public entry fun graduate_student(voter_nft: &mut StudentVoterNFT) {
        voter_nft.is_graduated = true;
        voter_nft.voting_power = 0;
        voter_nft.name = b"Graduated";
        voter_nft.description = b"You are no longer eligible to vote.";
        voter_nft.image_url = b"https://i.ibb.co/fzq9JmxX/element5-digital-T9-CXBZLUvic-unsplash.jpg";
        event::emit(StudentGraduated { student_id: voter_nft.student_id });
    }

    // Register as candidate (Juniors/Seniors only)
    public entry fun register_candidate(
        voter_nft: &StudentVoterNFT,
        name: vector<String>,
        campaign_promises: vector<String>,
        ctx: &mut TxContext
    ) {
        assert!(voter_nft.voting_power >= 3, 1); // 3+ votes required
        let candidate = Candidate {
            id: object::new(ctx),
            student_id: voter_nft.student_id,
            name,
            campaign_promises,
            vote_count: 0,
        };
        transfer::transfer(candidate, tx_context::sender(ctx));
        event::emit(CandidateRegistered {
            student_id: voter_nft.student_id,
            name,
        });
    }

    // Cast a vote (one per student)
    public entry fun cast_vote(
        voter_nft: &mut StudentVoterNFT,
        candidate: &mut Candidate,
        ctx: &mut TxContext
    ) {
        assert!(!voter_nft.is_graduated, 2);
        assert!(!voter_nft.has_voted, 3); // Only one vote per election
        let vote = Vote {
            id: object::new(ctx),
            voter_id: voter_nft.student_id,
            candidate_id: candidate.student_id,
            voting_power: voter_nft.voting_power,
        };
        candidate.vote_count = candidate.vote_count + voter_nft.voting_power;
        voter_nft.has_voted = true;
        transfer::transfer(vote, tx_context::sender(ctx));
        event::emit(VoteCast {
            voter_id: voter_nft.student_id,
            candidate_id: candidate.student_id,
            voting_power: voter_nft.voting_power,
        });
    }

    /// ADMIN-ONLY: Tally votes and create results
    public entry fun tally_votes(
        admin: &AdminCap,
        _votes: vector<Vote>,
        candidates: vector<Candidate>,
        ctx: &mut TxContext
    ) {
        let mut i = 0;
        while (i < vector::length(&candidates)) {
            let candidate = vector::borrow(&candidates, i);
            let total_votes = candidate.vote_count;
            let result = ElectionResult {
                id: object::new(ctx),
                candidate_id: candidate.student_id,
                total_votes,
            };
            transfer::transfer(result, tx_context::sender(ctx));
            event::emit(ElectionResultsTallied {
                candidate_id: candidate.student_id,
                total_votes,
            });
            i = i + 1;
        };
        vector::destroy_empty(_votes);
        vector::destroy_empty(candidates);
    }

