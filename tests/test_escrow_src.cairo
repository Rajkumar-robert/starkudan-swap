#[cfg(test)]
mod TestEscrowSrc {
    use starknet::ContractAddress;
    use starknet::contract_address_const;
    use starknet::syscalls::deploy_syscall;
    use starknet::testing::{start_cheat_block_timestamp_global, stop_cheat_block_timestamp_global};
    use starkware.cairo.common.cairo_builtins import HashBuiltin;
    use starkware.cairo.common.uint256 import Uint256;
    use super::super::src::contracts::EscrowSrc;
    use super::super::src::interfaces::IERC20;
    use super::super::src::utils::HashUtils;

    // Mock ERC20 contract for testing
    #[starknet::contract]
    mod MockERC20 {
        use starknet::ContractAddress;
        use starkware.cairo.common.cairo_builtins import HashBuiltin;
        use starkware.cairo.common.uint256 import Uint256, uint256_add;

        #[storage]
        struct Storage {
            balances: LegacyMap::<ContractAddress, Uint256>,
            allowances: LegacyMap::<(ContractAddress, ContractAddress), Uint256>,
        }

        #[external(v0)]
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: Uint256) {
            let caller = starknet::get_caller_address();
            let current_balance = self.balances.read(caller);
            assert(current_balance >= amount, 'Insufficient balance');
            self.balances.write(caller, current_balance - amount);
            let recipient_balance = self.balances.read(recipient);
            self.balances.write(recipient, recipient_balance + amount);
        }

        #[external(v0)]
        fn transfer_from(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: Uint256) {
            let caller = starknet::get_caller_address();
            let allowance = self.allowances.read((sender, caller));
            assert(allowance >= amount, 'Insufficient allowance');
            let sender_balance = self.balances.read(sender);
            assert(sender_balance >= amount, 'Insufficient balance');
            self.balances.write(sender, sender_balance - amount);
            self.allowances.write((sender, caller), allowance - amount);
            let recipient_balance = self.balances.read(recipient);
            self.balances.write(recipient, recipient_balance + amount);
        }

        #[external(v0)]
        fn approve(ref self: ContractState, spender: ContractAddress, amount: Uint256) {
            let caller = starknet::get_caller_address();
            self.allowances.write((caller, spender), amount);
        }

        #[view]
        fn balance_of(self: @ContractState, account: ContractAddress) -> Uint256 {
            self.balances.read(account)
        }

        #[external(v0)]
        fn mint(ref self: ContractState, to: ContractAddress, amount: Uint256) {
            let current_balance = self.balances.read(to);
            self.balances.write(to, current_balance + amount);
        }
    }

    #[test]
    fn test_lock_and_claim() {
        // Deploy MockERC20
        let (token_address, _) = deploy_syscall(
            MockERC20::TEST_CLASS_HASH,
            0,
            array![].span(),
            false
        ).unwrap_syscall();

        // Deploy EscrowSrc
        let (escrow_address, _) = deploy_syscall(
            EscrowSrc::TEST_CLASS_HASH,
            0,
            array![].span(),
            false
        ).unwrap_syscall();

        // Setup addresses
        let sender = contract_address_const::<1>();
        let recipient = contract_address_const::<2>();
        let amount = Uint256 { low: 100, high: 0 };
        let secret = 42;
        let (hashlock, _) = HashUtils::hash_secret(secret, 0);
        let timelock = 1000;

        // Mint tokens to sender
        starknet::testing::set_caller_address(sender);
        MockERC20::mint(token_address, sender, amount);

        // Approve escrow contract
        MockERC20::approve(token_address, escrow_address, amount);

        // Lock funds
        EscrowSrc::lock_funds(
            escrow_address,
            1,
            recipient,
            token_address,
            amount,
            hashlock,
            timelock
        );

        // Check escrow details
        let escrow = EscrowSrc::get_escrow(escrow_address, 1);
        assert(escrow.sender == sender, 'Invalid sender');
        assert(escrow.recipient == recipient, 'Invalid recipient');
        assert(escrow.amount == amount, 'Invalid amount');
        assert(escrow.status == 0, 'Invalid status');

        // Claim funds
        starknet::testing::set_caller_address(recipient);
        EscrowSrc::claim_funds(escrow_address, 1, secret);

        // Verify claim
        let escrow_after = EscrowSrc::get_escrow(escrow_address, 1);
        assert(escrow_after.status == 1, 'Claim failed');
        let recipient_balance = MockERC20::balance_of(token_address, recipient);
        assert(recipient_balance == amount, 'Transfer failed');
    }

    #[test]
    fn test_refund_after_timelock() {
        // Deploy MockERC20
        let (token_address, _) = deploy_syscall(
            MockERC20::TEST_CLASS_HASH,
            0,
            array![].span(),
            false
        ).unwrap_syscall();

        // Deploy EscrowSrc
        let (escrow_address, _) = deploy_syscall(
            EscrowSrc::TEST_CLASS_HASH,
            0,
            array![].span(),
            false
        ).unwrap_syscall();

        // Setup addresses
        let sender = contract_address_const::<1>();
        let recipient = contract_address_const::<2>();
        let amount = Uint256 { low: 100, high: 0 };
        let secret = 42;
        let (hashlock, _) = HashUtils::hash_secret(secret, 0);
        let timelock = 1000;

        // Mint tokens to sender
        starknet::testing::set_caller_address(sender);
        MockERC20::mint(token_address, sender, amount);

        // Approve escrow contract
        MockERC20::approve(token_address, escrow_address, amount);

        // Lock funds
        EscrowSrc::lock_funds(
            escrow_address,
            1,
            recipient,
            token_address,
            amount,
            hashlock,
            timelock
        );

        // Simulate timelock expiration
        start_cheat_block_timestamp_global(timelock + 1);

        // Refund funds
        starknet::testing::set_caller_address(sender);
        EscrowSrc::refund_funds(escrow_address, 1);

        // Verify refund
        let escrow_after = EscrowSrc::get_escrow(escrow_address, 1);
        assert(escrow_after.status == 2, 'Refund failed');
        let sender_balance = MockERC20::balance_of(token_address, sender);
        assert(sender_balance == amount, 'Refund transfer failed');

        stop_cheat_block_timestamp_global();
    }
}