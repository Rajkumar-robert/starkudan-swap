use core::hash::{HashStateTrait, HashStateExTrait};
use core::poseidon::PoseidonTrait;

// Computes hash for a secret using Poseidon (recommended for Starknet)
fn compute_secret_hash(secret: felt252) -> felt252 {
    PoseidonTrait::new().update(secret).finalize()
}

// Verifies if secret matches hashlock using Poseidon
fn verify_secret(secret: felt252, hashlock: felt252) -> bool {
    compute_secret_hash(secret) == hashlock
}

// Original function updated with Poseidon
pub fn hash_secret(secret: felt252, hashlock: felt252) -> felt252 {
    if verify_secret(secret, hashlock) {
        1
    } else {
        0
    }
}

