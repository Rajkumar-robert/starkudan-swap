#[cfg(test)]
mod TestHTLCValidator {
    use starknet::syscalls::deploy_syscall;
    use starknet::testing::{start_cheat_block_timestamp_global, stop_cheat_block_timestamp_global};
    use starkware::cairo.common.cairo_builtins import HashBuiltin;
    use super::super::src::contracts::HTLCValidator;
    use super::super::src::utils::HashUtils;

    #[test]
    fn test_validate_htlc_success() {
        let (validator_address, _) = deploy_syscall(
            HTLCValidator::TEST_CLASS_HASH, 0, array![].span(), false
        )
            .unwrap_syscall();
        let validator_dispatcher = HTLCValidator::IDispatcher {
            contract_address: validator_address
        };

        let secret = 42;
        let (hashlock, _) = HashUtils::hash_secret(secret, 0);
        let timelock = 1000;

        // Set timestamp before timelock
        start_cheat_block_timestamp_global(timelock - 1);

        // Validate
        let result = validator_dispatcher.validate_htlc(secret, hashlock, timelock);
        assert(result == 1, 'Validation failed');

        stop_cheat_block_timestamp_global();
    }

    #[test]
    fn test_validate_htlc_invalid_secret() {
        let (validator_address, _) = deploy_syscall(
            HTLCValidator::TEST_CLASS_HASH, 0, array![].span(), false
        )
            .unwrap_syscall();
        let validator_dispatcher = HTLCValidator::IDispatcher {
            contract_address: validator_address
        };

        let secret = 42;
        let (hashlock, _) = HashUtils::hash_secret(secret, 0);
        let timelock = 1000;

        // Set timestamp before timelock
        start_cheat_block_timestamp_global(timelock - 1);

        // Validate with wrong secret
        let result = validator_dispatcher.validate_htlc(secret + 1, hashlock, timelock);
        assert(result == 0, 'Invalid secret passed');

        stop_cheat_block_timestamp_global();
    }

    #[test]
    fn test_validate_htlc_expired_timelock() {
        let (validator_address, _) = deploy_syscall(
            HTLCValidator::TEST_CLASS_HASH, 0, array![].span(), false
        )
            .unwrap_syscall();
        let validator_dispatcher = HTLCValidator::IDispatcher {
            contract_address: validator_address
        };

        let secret = 42;
        let (hashlock, _) = HashUtils::hash_secret(secret, 0);
        let timelock = 1000;

        // Set timestamp after timelock
        start_cheat_block_timestamp_global(timelock + 1);

        // Validate
        let result = validator_dispatcher.validate_htlc(secret, hashlock, timelock);
        assert(result == 0, 'Expired timelock passed');

        stop_cheat_block_timestamp_global();
    }
}