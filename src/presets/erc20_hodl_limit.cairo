#[starknet::contract]
mod ERC20HodlLimitContract {
    use core::debug::PrintTrait;
use starknet::ContractAddress;
    use openzeppelin::token::erc20::interface::IERC20Metadata;
    use openzeppelin::token::erc20::interface::{ IERC20, IERC20CamelOnly };
    use openzeppelin::access::ownable::interface::IOwnable;
    use degen::degen::hodl_limit::HodlLimitComponent::InternalTrait as HodlLimitInternalTrait;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait as OwnableInternalTrait;
    use openzeppelin::token::erc20::ERC20Component;
    use openzeppelin::access::ownable::OwnableComponent;

    use degen::degen::hodl_limit::HodlLimitComponent;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: HodlLimitComponent, storage: hodl_limit, event: HodlLimitEvent);

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // ERC20

    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl SafeAllowanceImpl = ERC20Component::SafeAllowanceImpl<ContractState>;
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl SafeAllowanceCamelImpl = ERC20Component::SafeAllowanceCamelImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    // Ownable

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableCamelOnlyImpl = OwnableComponent::OwnableCamelOnlyImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Hodl Limit

    #[abi(embed_v0)]
    impl HodlLimitImpl = HodlLimitComponent::HodlLimitImpl<ContractState>;
    impl HodlLimitInternalImpl = HodlLimitComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        hodl_limit: HodlLimitComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        HodlLimitEvent: HodlLimitComponent::Event,
    }

    /// Sets the token `name` and `symbol`.
    /// Mints `fixed_supply` tokens to `recipient`.
    /// Gives contract ownership to `recipient`.
    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
        fixed_supply: u256,
        recipient: ContractAddress,
    ) {
        self.erc20.initializer(name, symbol);
        self.erc20._mint(recipient, fixed_supply);
        self.ownable._transfer_ownership(recipient);
    }

    //
    // Hodl Limit
    //

    #[external(v0)]
    fn add_pool(ref self: ContractState, pool_address: ContractAddress) {
        self.ownable.assert_only_owner();

        self.hodl_limit._add_pool(:pool_address);
    }

    #[external(v0)]
    fn enable_hodl_limit(ref self: ContractState) {
        self.ownable.assert_only_owner();

        self.hodl_limit._enable_hodl_limit();
    }

    #[external(v0)]
    fn disable_hodl_limit(ref self: ContractState) {
        self.ownable.assert_only_owner();

        self.hodl_limit._disable_hodl_limit();
    }

    //
    // IERC20
    //

    #[external(v0)]
    impl IERC20Impl of IERC20<ContractState> {
        fn total_supply(self: @ContractState) -> u256 {
            self.erc20.total_supply()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc20.balance_of(:account)
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.erc20.allowance(:owner, :spender)
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let sender = starknet::get_caller_address();
            self._check_hodl_limit(:sender, :recipient, :amount);

            self.erc20.transfer(:recipient, :amount)
        }

        fn transfer_from(
            ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
        ) -> bool {
            self._check_hodl_limit(:sender, :recipient, :amount);

            self.erc20.transfer_from(:sender, :recipient, :amount)
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            self.erc20.approve(:spender, :amount)
        }
    }

    #[external(v0)]
    impl IERC20CamelOnlyImpl of IERC20CamelOnly<ContractState> {
        fn totalSupply(self: @ContractState) -> u256 {
            self.erc20.totalSupply()
        }

        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc20.balanceOf(:account)
        }

        fn transferFrom(
            ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
        ) -> bool {
            self._check_hodl_limit(:sender, :recipient, :amount);

            self.erc20.transferFrom(:sender, :recipient, :amount)
        }
    }

    //
    // Internals
    //

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _check_hodl_limit(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            let sender_is_owner = self.ownable.owner() == sender;

            // check hodl limit
            if (!sender_is_owner) {
                let recipient_balance = self.erc20.balance_of(account: recipient) + amount;
                self.hodl_limit._check_hodl_limit(:recipient, :recipient_balance);
            }
        }
    }
}
