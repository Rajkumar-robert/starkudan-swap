use starknet::get_block_timestamp;

pub fn check_timelock(timelock: u64) -> u8 {
    let now = get_block_timestamp();
    if now >= timelock {
        1
    } else {
        0
    }
}