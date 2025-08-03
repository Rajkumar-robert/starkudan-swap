use starkudan_swap::utils::hash_utils;
use starkudan_swap::utils::timestamp;

pub fn validate_htlc(secret: felt252, hashlock: felt252, timelock: u64) -> u8 {
    let hash_valid = hash_utils::hash_secret(secret, hashlock);
    let time_valid = timestamp::check_timelock(timelock);
     if hash_valid == 1 && time_valid == 0 {
        1   
    } else {
        0
    }
}


