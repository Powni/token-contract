use starknet::ContractAddress;

#[starknet::interface]
trait IHodlLimit<TState> {
    fn is_pool(self: @TState, pool_address: ContractAddress) -> bool;
    fn is_hodl_limit_enabled(self: @TState) -> bool;
}
