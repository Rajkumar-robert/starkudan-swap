#[starknet::contract]
mod EscrowFactory {
    use starknet::storage::{
    Map,
    StoragePointerReadAccess, StoragePointerWriteAccess,
    StorageMapReadAccess, StorageMapWriteAccess,
    };
    use starknet::ContractAddress;
    use starknet::syscalls::deploy_syscall;
    use starknet::{
    ClassHash,
    get_caller_address,
};


use core::integer::u256;
use crate::interfaces::iescrow_src::{
    IEscrowSrcDispatcher,
    IEscrowSrcDispatcherTrait,
};

    #[storage]
    struct Storage {
        deployed_escrows: Map<u64, ContractAddress>,
        escrow_count: u64,
    }

    #[external(v0)]
    fn deploy_escrow(
        ref self: ContractState,
        class_hash: ClassHash,
        recipient: ContractAddress,
        token: ContractAddress,
        amount: u256,
        hashlock: felt252,
        timelock: u64
    ) -> ContractAddress {
        let _caller = get_caller_address();
        let escrow_id: u64 = self.escrow_count.read();

        let (escrow_address, _ ) = deploy_syscall(
            class_hash,
            escrow_id.into(),
            array![].span(),
            false
        ).unwrap();

        self.escrow_count.write(escrow_id + 1);
        self.deployed_escrows.write(escrow_id.into(), escrow_address);

        IEscrowSrcDispatcher { contract_address: escrow_address }
            .lock_funds(
                escrow_id.into(),
                recipient, token, amount, hashlock, timelock
            );

        escrow_address
    }


    fn get_escrow_address(
        self: @ContractState,
        escrow_id: u64
    ) -> ContractAddress {
        self.deployed_escrows.read(escrow_id.into())
    }
}
