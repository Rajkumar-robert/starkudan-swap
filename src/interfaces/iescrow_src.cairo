use starknet::ContractAddress;
use core::serde::Serde;

#[starknet::interface]
pub trait IEscrowSrc<TContractState> {
    fn lock_funds(
        ref self: TContractState,
        escrow_id: felt252,
        recipient: ContractAddress,
        token: ContractAddress,
        amount: u256,
        hashlock: felt252,
        timelock: u64
    );

    fn claim_funds(
        ref self: TContractState,
        escrow_id: felt252,
        secret: felt252
    );

    fn refund_funds(
        ref self: TContractState,
        escrow_id: felt252
    );

    #[view]
    fn get_escrow(
        self: @TContractState,
        escrow_id: felt252
    ) -> EscrowDetails;
}

#[derive(Drop, Copy,Serde, starknet::Store)]
pub struct EscrowDetails {
    sender: ContractAddress,
    recipient: ContractAddress,
    token: ContractAddress,
    amount: u256,
    hashlock: felt252,
    timelock: u64,
    status: u8
}