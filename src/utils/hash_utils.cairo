use starkware::cairo::common::hash::hash2;
use starkware::cairo::common::cairo_builtins::HashBuiltin;

fn hash_secret(secret: felt252, hashlock: felt252) {
    let computed_hash = hash2(secret, 0);
    assert(computed_hash == hashlock, 'Invalid secret');
}
