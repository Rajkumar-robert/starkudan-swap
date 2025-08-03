#[starknet::contract]
mod HTLCValidator {
    use starknet::get_block_timestamp;
    use starkudan_swap::utils::hash_utils;
    use starkudan_swap::utils::timestamp;

    // Validate hashlock and timelock
    #[view]
    fn validate_htlc(secret: felt252, hashlock: felt252, timelock: u64) {
        hash_utils::hash_secret(secret, hashlock);
        timestamp::check_timelock(timelock);
    }
}

