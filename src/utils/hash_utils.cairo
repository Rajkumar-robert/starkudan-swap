use starknet::hash::hash2;

fn hash_secret(secret: felt252, hashlock: felt252) -> felt252 {
    let (computed_hash) = hash2(secret, 0);
    if computed_hash == hashlock {
        return 1;
    }
    return 0;
}