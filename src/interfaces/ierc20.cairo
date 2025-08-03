use starknet::ContractAddress;
use starkware::cairo::common::uint256::Uint256;

#[starknet::interface]
trait IERC20<TContractState> {
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: Uint256);
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: Uint256
    );
    fn balance_of(self: @TContractState, account: ContractAddress) -> Uint256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> Uint256;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: Uint256);
}

