#[starknet::interface]
trait IERC20<TContractState> {
    fn transfer(self: @TContractState, recipient: ContractAddress, amount: Uint256);
    fn transfer_from(
        self: @TContractState, 
        sender: ContractAddress, 
        recipient: ContractAddress, 
        amount: Uint256
    );
    fn balance_of(self: @TContractState, account: ContractAddress) -> Uint256;
}