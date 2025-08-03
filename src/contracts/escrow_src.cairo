#[starknet::contract]
mod EscrowSrc {
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starkware::cairo::common::uint256::Uint256;
    use starkudan_swap::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starkudan_swap::utils::hash_utils;
    use starkudan_swap::utils::timestamp;
    use starkudan_swap::contracts::htlc_validator::HTLCValidator;

    // Storage for escrow details
    #[storage]
    struct Storage {
        escrows: LegacyMap<felt252, EscrowDetails>,
    }

    #[derive(Copy, Drop, starknet::Store)]
    struct EscrowDetails {
        sender: ContractAddress,
        recipient: ContractAddress,
        token: ContractAddress,
        amount: Uint256,
        hashlock: felt252,
        timelock: u64,
        status: u8, // 0: Open, 1: Claimed, 2: Refunded
    }

    // Lock funds in escrow
    #[external(v0)]
    fn lock_funds(
        ref self: ContractState,
        escrow_id: felt252,
        recipient: ContractAddress,
        token: ContractAddress,
        amount: Uint256,
        hashlock: felt252,
        timelock: u64
    ) {
        let caller = get_caller_address();
        let contract_address = get_contract_address();

        IERC20Dispatcher { contract_address: token }.transfer_from(caller, contract_address, amount);

        self.escrows
            .write(
                escrow_id,
                EscrowDetails {
                    sender: caller,
                    recipient: recipient,
                    token: token,
                    amount: amount,
                    hashlock: hashlock,
                    timelock: timelock,
                    status: 0
                }
            );
    }

    // Claim funds with secret
    #[external(v0)]
    fn claim_funds(ref self: ContractState, escrow_id: felt252, secret: felt252) {
        let escrow = self.escrows.read(escrow_id);
        assert(escrow.status == 0, 'Escrow not open');
        HTLCValidator::validate_htlc(secret, escrow.hashlock, escrow.timelock);

        IERC20Dispatcher { contract_address: escrow.token }.transfer(escrow.recipient, escrow.amount);

        self.escrows
            .write(
                escrow_id,
                EscrowDetails {
                    sender: escrow.sender,
                    recipient: escrow.recipient,
                    token: escrow.token,
                    amount: escrow.amount,
                    hashlock: escrow.hashlock,
                    timelock: escrow.timelock,
                    status: 1
                }
            );
    }

    // Refund funds after timelock expires
    #[external(v0)]
    fn refund_funds(ref self: ContractState, escrow_id: felt252) {
        let escrow = self.escrows.read(escrow_id);
        assert(escrow.status == 0, 'Escrow not open');
        timestamp::check_timelock(escrow.timelock);

        IERC20Dispatcher { contract_address: escrow.token }.transfer(escrow.sender, escrow.amount);

        self.escrows
            .write(
                escrow_id,
                EscrowDetails {
                    sender: escrow.sender,
                    recipient: escrow.recipient,
                    token: escrow.token,
                    amount: escrow.amount,
                    hashlock: escrow.hashlock,
                    timelock: escrow.timelock,
                    status: 2
                }
            );
    }

    // View function to get escrow details
    #[view]
    fn get_escrow(self: @ContractState, escrow_id: felt252) -> EscrowDetails {
        self.escrows.read(escrow_id)
    }
}