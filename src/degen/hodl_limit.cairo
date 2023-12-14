#[starknet::component]
mod HodlLimitComponent {
    use openzeppelin::token::erc20::interface::IERC20;
    use openzeppelin::token::erc20::ERC20Component;

    use degen::degen::interface;

    const HODL_LIMIT: u16 = 100; // 1%

    #[storage]
    struct Storage {
        _is_hodl_limit_enabled: bool,
        _pool_addresses: LegacyMap<starknet::ContractAddress, bool>,
    }

    mod Errors {
        const HODL_LIMIT_REACHED: felt252 = '1% Hodl limit reached';
    }

    //
    // IHodlLimit
    //

    #[embeddable_as(HodlLimitImpl)]
    impl HodlLimit<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
    > of interface::IHodlLimit::<ComponentState<TContractState>> {
        fn is_pool(self: @ComponentState<TContractState>, pool_address: starknet::ContractAddress) -> bool {
            self._pool_addresses.read(pool_address)
        }

        fn is_hodl_limit_enabled(self: @ComponentState<TContractState>) -> bool {
            self._is_hodl_limit_enabled.read()
        }
    }

    //
    // Internals
    //

    #[generate_trait]
    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn _check_hodl_limit(
            ref self: ComponentState<TContractState>,
            recipient: starknet::ContractAddress,
            recipient_balance: u256
        ) {
            let is_hodl_limit_enabled = self._is_hodl_limit_enabled.read();

            if (is_hodl_limit_enabled && !self._pool_addresses.read(recipient)) {
                let erc20_component = get_dep_component!(self, ERC20);

                let max_amount = erc20_component.total_supply() / (10_000 / HODL_LIMIT).into();
                assert(recipient_balance <= max_amount, Errors::HODL_LIMIT_REACHED);
            }
        }

        fn _add_pool(ref self: ComponentState<TContractState>, pool_address: starknet::ContractAddress) {
            self._pool_addresses.write(pool_address, true);
        }

        fn _enable_hodl_limit(ref self: ComponentState<TContractState>) {
            self._is_hodl_limit_enabled.write(true);
        }

        fn _disable_hodl_limit(ref self: ComponentState<TContractState>) {
            self._is_hodl_limit_enabled.write(false);
        }
    }
}
