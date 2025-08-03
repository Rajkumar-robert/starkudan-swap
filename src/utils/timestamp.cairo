use starknet::get_block_timestamp;

fn check_timelock(timelock: u64) {
    let current_timestamp = get_block_timestamp();
    assert(current_timestamp >= timelock, 'Timelock not expired');
}