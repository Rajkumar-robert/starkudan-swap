#[starknet::contract]
mod EscrowFactory {
    use starknet::{ContractAddress, get_caller_address, ClassHash};
    use starknet::storage::Map;
    use starknet::syscalls::deploy_syscall;
    use starkudan_swap::interfaces::iescrow_src::{IEscrowSrcDispatcher, IEscrowSrcDispatcherTrait};

    // Storage for deployed escrows
    #[storage]
    struct Storage {
        deployed_escrows: Map<u64, ContractAddress>,
        escrow_count: u64,
    }

    // Deploy a new EscrowSrc contract
    #[abi(embed_v0)]
    fn deploy_escrow(
        ref self: ContractState,
        class_hash: ClassHash,
        recipient: ContractAddress,
        token: ContractAddress,
        amount: u256,
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
