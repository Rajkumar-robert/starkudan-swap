#[cfg(test)]
mod TestEscrowFactory {
    use starknet::ContractAddress;
    use starknet::contract_address_const;
    use starknet::syscalls::deploy_syscall;
    use starkware.cairo.common.cairo_builtins import HashBuiltin;

    use super::super::src::contracts::{EscrowSrc, EscrowFactory};
    use super::super::src::interfaces::IERC20;
    use super::super::src::utils::HashUtils;

    // Reuse MockERC20 from test_escrow_src.cairo
    #[starknet::contract]
    mod MockERC20 {
        // Same as in test_escrow_src.cairo
        use starknet::ContractAddress;
        use starkware::cairo.common.cairo_builtins import HashBuiltin;
    

        #[storage]
        struct Storage {
            balances: LegacyMap::<ContractAddress, u256>,
            allowances: LegacyMap::<(ContractAddress, ContractAddress), u256>,
        }

        #[external(v0)]
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            let caller = starknet::get_caller_address();
            let current_balance = self.balances.read(caller);
            assert(current_balance >= amount, 'Insufficient balance');
            self.balances.write(caller, current_balance - amount);
            let recipient_balance = self.balances.read(recipient);
            let (new_recipient_balance, _) = uint256_add(recipient_balance, amount);
            self.balances.write(recipient, new_recipient_balance);
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
            let (new_recipient_balance, _) = uint256_add(recipient_balance, amount);
            self.balances.write(recipient, new_recipient_balance);
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
            let (new_balance, _) = uint256_add(current_balance, amount);
            self.balances.write(to, new_balance);
        }
    }

    #[test]
    fn test_deploy_escrow() {
        // Deploy MockERC20
        let (token_address, _) = deploy_syscall(
            MockERC20::TEST_CLASS_HASH,
            0,
            array![].span(),
            false
        ).unwrap_syscall();
        let token_dispatcher = IERC20Dispatcher { contract_address: token_address };

        // Deploy EscrowFactory
        let (factory_address, _) = deploy_syscall(
            EscrowFactory::TEST_CLASS_HASH,
            0,
            array![].span(),
            false
        ).unwrap_syscall();
        let factory_dispatcher = EscrowFactory::IDispatcher { contract_address: factory_address };

        // Setup addresses
        let sender = contract_address_const::<1>();
        let recipient = contract_address_const::<2>();
        let amount = Uint256 { low: 100, high: 0 };
        let secret = 42;
        let (hashlock, _) = HashUtils::hash_secret(secret, 0);
        let timelock = 1000;

        // Mint tokens to sender
        starknet::testing::set_caller_address(sender);
        token_dispatcher.mint(sender, amount);

        // Approve factory contract
        token_dispatcher.approve(factory_address, amount);

        // Deploy escrow via factory
        let escrow_class_hash = EscrowSrc::TEST_CLASS_HASH;
        let escrow_address = factory_dispatcher.deploy_escrow(
            escrow_class_hash,
            recipient,
            token_address,
            amount,
            hashlock,
            timelock
        );

        // Verify escrow deployment
        let deployed_address = factory_dispatcher.get_escrow_address(0);
        assert(deployed_address == escrow_address, 'Invalid escrow address');

        // Check escrow details
        let escrow_dispatcher = EscrowSrc::IDispatcher { contract_address: escrow_address };
        let escrow = escrow_dispatcher.get_escrow(0);
        assert(escrow.sender == sender, 'Invalid sender');
        assert(escrow.recipient == recipient, 'Invalid recipient');
        assert(escrow.amount == amount, 'Invalid amount');
        assert(escrow.status == 0, 'Invalid status');
    }
}
