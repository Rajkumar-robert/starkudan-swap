use openzeppelin_token::erc20::interface::{
    IERC20Dispatcher, IERC20DispatcherTrait
};
use starknet::ContractAddress;
use starknet::get_caller_address;
use starknet::get_contract_address;

use core::integer::u256;
use core::serde::Serde;
use starkudan_swap::interfaces::iescrow_src::IEscrowSrc;
// use starkudan_swap::interfaces::iescrow_src::{EscrowDetails as IEscrowDetails};
use starkudan_swap::utils::htlc_validator;
use starkudan_swap::utils::timestamp;

#[starknet::contract]
mod EscrowSrc {
    use crate::interfaces::iescrow_src::EscrowDetails as IEscrowDetails;

    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    #[storage]
    struct Storage {
        escrows: Map<felt252, IEscrowDetails>,
    }

    #[abi(embed_v0)]
    impl EscrowSrcImpl of IEscrowSrc<ContractState> {


        fn lock_funds(
            ref self: ContractState,
            escrow_id: felt252,
            recipient: ContractAddress,
            token: ContractAddress,
            amount: u256,
            hashlock: felt252,
            timelock: u64
        ) {
            let sender = get_caller_address();
            let me = get_contract_address();

            let ok: bool = IERC20Dispatcher { contract_address: token }
                .transfer_from(sender, me, amount);
            assert(ok, 'ERC20 transfer_from failed');

            let escrow = IEscrowDetails {
                sender,
                recipient,
                token,
                amount,
                hashlock,
                timelock,
                status: 0_u8,
            };
            self.escrows.write(escrow_id, escrow);
        }


        fn claim_funds(
            ref self: ContractState,
            escrow_id: felt252,
            secret: felt252
        ) {
            let escrow = self.escrows.read(escrow_id);
            assert(escrow.status == 0_u8, 'Swap closed or claimed');

            let valid_hash: u8 = htlc_validator::validate_htlc(
                secret,
                escrow.hashlock,
                escrow.timelock
            );
            assert(valid_hash == 1_u8, 'Invalid preimage or still before timelock');

            let sent: bool = IERC20Dispatcher { contract_address: escrow.token }
                .transfer(escrow.recipient, escrow.amount);
            assert(sent, 'ERC20 transfer failed');

            let updated = IEscrowDetails {
                status: 1_u8,
                ..escrow
            };
            self.escrows.write(escrow_id, updated);
        }


        fn refund_funds(
            ref self: ContractState,
            escrow_id: felt252
        ) {
            let escrow = self.escrows.read(escrow_id);
            assert(escrow.status == 0_u8, 'Already claimed or refunded');

            let expired: u8 = timestamp::check_timelock(escrow.timelock);
            assert(expired == 1_u8, 'Timelock not reached');

            let reverted: bool = IERC20Dispatcher { contract_address: escrow.token }
                .transfer(escrow.sender, escrow.amount);
            assert(reverted, 'ERC20 refund failed');

            let updated = IEscrowDetails {
                status: 2_u8,
                ..escrow
            };
            self.escrows.write(escrow_id, updated);
        }

        #[view]
        fn get_escrow(
            self: @ContractState,
            escrow_id: felt252
        ) -> IEscrowDetails {
            self.escrows.read(escrow_id)
        }
    }
}
