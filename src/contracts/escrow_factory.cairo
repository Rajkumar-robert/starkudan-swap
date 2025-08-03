#[starknet::contract]
mod EscrowFactory {
    use starknet::ContractAddress;
    use starknet::contract_address_const;
    use starknet::get_caller_address;
    use starknet::class_hash::ClassHash;
    use starknet::syscalls::deploy_syscall;
    use starkware::cairo::common::uint256::Uint256;
    use starkudan_swap::contracts::escrow_src::{IEscrowSrcDispatcher, IEscrowSrcDispatcherTrait};

    // Storage for deployed escrows
    #[storage]
    struct Storage {
        deployed_escrows: LegacyMap<felt252, ContractAddress>,
        escrow_count: u64,
    }

    // Deploy a new EscrowSrc contract
    #[external(v0)]
    fn deploy_escrow(
        ref self: ContractState,
        class_hash: ClassHash,
        recipient: ContractAddress,
        token: ContractAddress,
        amount: Uint256,
        hashlock: felt252,
        timelock: u64
    ) -> ContractAddress {
        let caller = get_caller_address();
        let escrow_id = self.escrow_count.read();

        // Deploy new EscrowSrc contract
        let (escrow_address, _) = deploy_syscall(
            class_hash, escrow_id.into(), array![].span(), false
        )
            .unwrap();

        self.escrow_count.write(escrow_id + 1);
        self.deployed_escrows.write(escrow_id.into(), escrow_address);

        IEscrowSrcDispatcher { contract_address: escrow_address }
            .lock_funds(escrow_id.into(), recipient, token, amount, hashlock, timelock);

        escrow_address
    }

    #[view]
    fn get_escrow_address(self: @ContractState, escrow_id: u64) -> ContractAddress {
        self.deployed_escrows.read(escrow_id.into())
    }
}
