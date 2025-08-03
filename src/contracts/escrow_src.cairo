#[starknet::contract]
mod EscrowSrc {
    use starknet::{ContractAddress, get_caller_address, get_contract_address, StorageMap};
    use starknet::Uint256;
    use starkudan_swap::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starkudan_swap::utils::{hash_utils, timestamp};
    use starkudan_swap::contracts::htlc_validator;

    

    // Storage for escrow details
    #[storage]
    struct Storage {
        escrows: Map<felt252, EscrowDetails>,
    }

  #[derive(Copy, Drop)]
    struct EscrowDetails {
        sender: ContractAddress,
        recipient: ContractAddress,
        token: ContractAddress,
        amount: Uint256,
        hashlock: felt252,
        timelock: u64,
        status: felt252, // 0: Open, 1: Claimed, 2: Refunded
    }

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

        self.escrows.write(
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

    #[external(v0)]
    fn claim_funds(ref self: ContractState, escrow_id: felt252, secret: felt252) {
        let escrow = self.escrows.read(escrow_id);
        assert(escrow.status == 0, 'Escrow not open');
        let is_valid = htlc_validator::validate_htlc(secret, escrow.hashlock, escrow.timelock);
        assert(is_valid, 'Invalid secret or timelock');

        IERC20Dispatcher { contract_address: escrow.token }.transfer(escrow.recipient, escrow.amount);

        self.escrows.write(
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

    #[external(v0)]
    fn refund_funds(ref self: ContractState, escrow_id: felt252) {
        let escrow = self.escrows.read(escrow_id);
        assert(escrow.status == 0, 'Escrow not open');
        let is_expired = starkudan_swap::utils::timestamp::check_timelock(escrow.timelock);
        assert(is_expired, 'Timelock not expired');

        IERC20Dispatcher { contract_address: escrow.token }.transfer(escrow.sender, escrow.amount);

        self.escrows.write(
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

    #[external(v0)]
    fn get_escrow(self: @ContractState, escrow_id: felt252) -> EscrowDetails {
        self.escrows.read(escrow_id)
    }
}