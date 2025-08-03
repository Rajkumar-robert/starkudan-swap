// Remove contract attribute, make it a library
mod htlc_validator {
    use super::super::hash_utils;
    use super::super::timestamp;
    
    fn validate_htlc(secret: felt252, hashlock: felt252, timelock: u64) -> bool {
        let hash_valid = hash_utils::hash_secret(secret, hashlock);
        let time_valid = timestamp::check_timelock(timelock);
        hash_valid == 1 && time_valid == 0
    }
}