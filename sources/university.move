module university::university;
    use std::string::String;
    use sui::event;
    use sui::url::{Self, Url};
    use sui::table::{Self, Table};

    // === ADMIN CAPABILITY ===
    public struct AdminCap has key {
        id: UID,
    }

    // === STRUCTS ===
    public struct StudentVoterNFT has key, store {
        id: UID,
        name: String,
        description: String,
        image_url: Url,
        student_id: u64,
        voting_power: u64,
        is_graduated: bool,
        last_updated: u64,
        has_voted: bool,
    }

    public struct Candidate has key, store {
        id: UID,
        student_id: u64,
        name: String,
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

    public struct Election has key, store {
        id: UID,
        election_id: u64,
        election_type: String,
        is_active: bool,
        candidates: Table<ID, Candidate>,
        candidate_ids: vector<ID>,
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
        name: String,
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

    public struct ElectionCreated has copy, drop {
        election_id: u64,
        election_type: String,
    }

    // === ENTRY FUNCTIONS ===
    /// Called once at module publish to mint the admin capability.
    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx));
    }

    /// ADMIN-ONLY: Start a new election
    public entry fun start_election(
        _admin: &AdminCap,
        election_id: u64,
        election_type: String,
        ctx: &mut TxContext){
        let election = Election {
            id: object::new(ctx),
            election_id,
            election_type,
            is_active: true,
            candidates: table::new(ctx),
            candidate_ids: vector::empty<ID>(),
        };
        
        transfer::share_object(election);
        event::emit(ElectionCreated { election_id, election_type });
    }

    /// ADMIN-ONLY: Mint a new student NFT
    public entry fun create_student_voting_nft(
        _admin: &AdminCap,
        student_id: u64,
        ctx: &mut TxContext
    ) {
        let current_epoch = tx_context::epoch(ctx);
        let voter_nft = StudentVoterNFT {
            id: object::new(ctx),
            name: b"University Voter ID".to_string(),
            description: b"This is a unique voter ID for university elections".to_string(),
            image_url: url::new_unsafe_from_bytes(b"https://i.ibb.co/fzq9Jmx/element5-digital-T9-CXBZLUvic-unsplash.jpg"),
            student_id,
            voting_power: 1,
            is_graduated: false,
            last_updated: current_epoch,
            has_voted: false,
        };
        transfer::transfer(voter_nft, tx_context::sender(ctx));
        event::emit(StudentVoterNFTCreated { student_id, voting_power: 1 });
    }

    /// Update voting power (simulate academic progression, once per year)
    public entry fun update_voting_power(
        voter_nft: &mut StudentVoterNFT,
        current_time: u64
    ) {
        assert!(!voter_nft.is_graduated, 0);
        let time_elapsed = current_time - voter_nft.last_updated;
        if (time_elapsed >= 365 * 24 * 60 * 60 && voter_nft.voting_power < 4) {
            voter_nft.voting_power = voter_nft.voting_power + 1;
            voter_nft.last_updated = current_time;
            let mut new_description = b"Your voting power is now: ".to_string();
            new_description.append(voter_nft.voting_power.to_string());
            voter_nft.description = new_description;
            event::emit(VotingPowerUpdated {
                student_id: voter_nft.student_id,
                new_voting_power: voter_nft.voting_power,
            });
        }
    }

    /// Graduate student (deactivate NFT)
    public entry fun graduate_student(voter_nft: &mut StudentVoterNFT) {
        voter_nft.is_graduated = true;
        voter_nft.voting_power = 0;
        voter_nft.name = b"Graduated".to_string();
        voter_nft.description = b"You are no longer eligible to vote.".to_string();
        voter_nft.image_url = url::new_unsafe_from_bytes(b"https://i.ibb.co/graduated-image.jpg");
        event::emit(StudentGraduated { student_id: voter_nft.student_id });
    }

    /// Register as candidate (Juniors/Seniors only)
    public entry fun register_candidate(
        voter_nft: &StudentVoterNFT,
        election: &mut Election,
        name: String,
        campaign_promises: vector<String>,
        ctx: &mut TxContext
    ) {
        let candidate = Candidate {
            id: object::new(ctx),
            student_id: voter_nft.student_id,
            name,
            campaign_promises,
            vote_count: 0,
        };
        let candidate_id = object::uid_to_inner(&candidate.id);
        table::add(&mut election.candidates, candidate_id, candidate);
        vector::push_back(&mut election.candidate_ids, candidate_id);
        event::emit(CandidateRegistered {
            student_id: voter_nft.student_id,
            name,
        });
    }

    /// Cast a vote (one per student)
    public entry fun cast_vote(
        voter_nft: &mut StudentVoterNFT,
        election: &mut Election,
        candidate_id: ID,
        ctx: &mut TxContext
    ) {
        assert!(!voter_nft.is_graduated, 2);
        assert!(!voter_nft.has_voted, 3);
        assert!(election.is_active, 4);
        assert!(table::contains(&election.candidates, candidate_id), 5);
        let candidate = table::borrow_mut(&mut election.candidates, candidate_id);
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

    /// ADMIN-ONLY: Tally votes for an election
    public entry fun tally_votes(
        _admin: &AdminCap,
        election: &mut Election,
        ctx: &mut TxContext
    ) {
        let mut i = 0;
        while (i < vector::length(&election.candidate_ids)) {
            let candidate_id = *vector::borrow(&election.candidate_ids, i);
            let candidate = table::borrow(&election.candidates, candidate_id);
            let candidate_student_id = candidate.student_id;
            let total_votes = candidate.vote_count;
            let result = ElectionResult {
                id: object::new(ctx),
                candidate_id: candidate_student_id,
                total_votes,
            };
            transfer::transfer(result, tx_context::sender(ctx));
            event::emit(ElectionResultsTallied {
                candidate_id: candidate_student_id,
                total_votes,
            });
            i = i + 1;
        };
        election.is_active = false;
    }

    /// ADMIN-ONLY: Reset voting status for a new election
    public entry fun reset_voting_status(
        _admin: &AdminCap,
        voter_nft: &mut StudentVoterNFT
    ) {
        assert!(!voter_nft.is_graduated, 1);
        voter_nft.has_voted = false;
    }
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        transfer::transfer(AdminCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx));
    }
public fun get_candidate_id(election: &Election, index: u64): ID {
        assert!(index < vector::length(&election.candidate_ids), 0);
        *vector::borrow(&election.candidate_ids, index)
    }