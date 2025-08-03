use starknet::get_block_timestamp;

fn check_timelock(timelock: u64) -> u8 {
    let current_timestamp = get_block_timestamp();
    if current_timestamp >= timelock {
        1
    } else {
        0
    }
}