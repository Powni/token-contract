use starknet::{ ContractAddress, testing };
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::token::erc20::ERC20Component::Transfer;
use openzeppelin::access::ownable::OwnableComponent::OwnershipTransferred;

use degen::degen::interface::IHodlLimit;
use degen::presets::erc20_hodl_limit::ERC20HodlLimitContract;
use degen::presets::interface::{ ERC20HodlLimitABIDispatcher, ERC20HodlLimitABIDispatcherTrait };
use degen::test::utils;
use degen::test::utils::constants;

//
// Tests
//

fn setup_dispatcher_with_event() -> ERC20HodlLimitABIDispatcher {
    let mut calldata = array![];

    calldata.append_serde(constants::NAME);
    calldata.append_serde(constants::SYMBOL);
    calldata.append_serde(constants::SUPPLY);
    calldata.append_serde(constants::OWNER());

    // execute as owner
    testing::set_contract_address(constants::OWNER());

    let address = utils::deploy(ERC20HodlLimitContract::TEST_CLASS_HASH, calldata);

    ERC20HodlLimitABIDispatcher { contract_address: address }
}

fn setup_dispatcher() -> ERC20HodlLimitABIDispatcher {
    let dispatcher = setup_dispatcher_with_event();
    utils::drop_event(dispatcher.contract_address);
    dispatcher
}

//
// constructor
//

#[test]
#[available_gas(2000000)]
fn test_constructor() {
    let mut dispatcher = setup_dispatcher_with_event();

    assert(dispatcher.name() == constants::NAME, 'Should be NAME');
    assert(dispatcher.symbol() == constants::SYMBOL, 'Should be SYMBOL');
    assert(dispatcher.decimals() == constants::DECIMALS, 'Should be DECIMALS');
    assert(dispatcher.total_supply() == constants::SUPPLY, 'Should equal SUPPLY');
    assert(dispatcher.balance_of(constants::OWNER()) == constants::SUPPLY, 'Should equal SUPPLY');
    assert(dispatcher.owner() == constants::OWNER(), 'Should be OWNER');

    // Check events
    assert_event_transfer(
        contract: dispatcher.contract_address,
        from: constants::ZERO(),
        to: constants::OWNER(),
        value: constants::SUPPLY
    );
    assert_event_ownership_transferred(
        contract: dispatcher.contract_address,
        previous_owner: constants::ZERO(),
        new_owner: constants::OWNER()
    );
    utils::assert_no_events_left(address: dispatcher.contract_address);
}

//
// Enable hodl limit
//

#[test]
#[available_gas(20000000)]
fn test_enable_hodl_limit() {
    let mut dispatcher = setup_dispatcher();

    assert(!dispatcher.is_hodl_limit_enabled(), 'bad hodl limit status before');

    dispatcher.enable_hodl_limit();

    assert(dispatcher.is_hodl_limit_enabled(), 'bad hodl limit status after');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_enable_hodl_limit_from_zero() {
    let mut dispatcher = setup_dispatcher();

    // execute as zero
    testing::set_contract_address(constants::ZERO());

    dispatcher.enable_hodl_limit();
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_enable_hodl_limit_from_unauthorized() {
    let mut dispatcher = setup_dispatcher();

    // execute as other
    testing::set_contract_address(constants::OTHER());

    dispatcher.enable_hodl_limit();
}

//
// Disable hodl limit
//

#[test]
#[available_gas(20000000)]
fn test_disable_hodl_limit() {
    let mut dispatcher = setup_dispatcher();

    // enable hodl limit
    dispatcher.enable_hodl_limit();

    assert(dispatcher.is_hodl_limit_enabled(), 'bad hodl limit status before');

    dispatcher.disable_hodl_limit();

    assert(!dispatcher.is_hodl_limit_enabled(), 'bad hodl limit status after');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_disable_hodl_limit_from_zero() {
    let mut dispatcher = setup_dispatcher();

    // enable hodl limit
    dispatcher.enable_hodl_limit();

    // execute as zero
    testing::set_contract_address(constants::ZERO());

    dispatcher.disable_hodl_limit();
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_disable_hodl_limit_from_unauthorized() {
    let mut dispatcher = setup_dispatcher();

    // enable hodl limit
    dispatcher.enable_hodl_limit();

    // execute as other
    testing::set_contract_address(constants::OTHER());

    dispatcher.disable_hodl_limit();
}

//
// Add pool
//

#[test]
#[available_gas(20000000)]
fn test_add_pool() {
    let mut dispatcher = setup_dispatcher();

    assert(!dispatcher.is_pool(constants::OTHER_POOL()), 'bad pool status before');

    dispatcher.add_pool(constants::OTHER_POOL());

    assert(dispatcher.is_pool(constants::OTHER_POOL()), 'bad pool status after');
}

#[test]
#[available_gas(20000000)]
fn test_add_multiple_pools() {
    let mut dispatcher = setup_dispatcher();

    assert(!dispatcher.is_pool(constants::POOL()), 'bad pool status before');
    assert(!dispatcher.is_pool(constants::OTHER_POOL()), 'bad other pool status before');

    dispatcher.add_pool(constants::POOL());
    dispatcher.add_pool(constants::OTHER_POOL());

    assert(dispatcher.is_pool(constants::POOL()), 'bad pool status after');
    assert(dispatcher.is_pool(constants::OTHER_POOL()), 'bad other pool status after');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_add_pool_from_zero() {
    let mut dispatcher = setup_dispatcher();

    // execute as zero
    testing::set_contract_address(constants::ZERO());

    dispatcher.add_pool(constants::OTHER_POOL());
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_add_pool_from_unauthorized() {
    let mut dispatcher = setup_dispatcher();

    // execute as other
    testing::set_contract_address(constants::OTHER());

    dispatcher.add_pool(constants::OTHER_POOL());
}

//
// Transfer
//

#[test]
#[available_gas(20000000)]
fn test_transfer() {
    let mut dispatcher = setup_dispatcher();

    // transfer
    assert(dispatcher.transfer(recipient: constants::RECIPIENT(), amount: constants::VALUE), 'Should return true');

    // check balances
    assert(
        dispatcher.balance_of(constants::OWNER()) == constants::SUPPLY - constants::VALUE,
        'Should equal SUPPLY - VALUE'
    );
    assert(
        dispatcher.balance_of(constants::RECIPIENT()) == constants::VALUE,
        'Should equal VALUE'
    );
}

#[test]
#[available_gas(20000000)]
fn test_transfer_with_hodl_limit() {
    let mut dispatcher = setup_dispatcher();
    let value = constants::SUPPLY / 100; // 1%

    // enable hodl limit
    dispatcher.enable_hodl_limit();

    // renounce ownership
    dispatcher.renounce_ownership();

    // transfer
    assert(dispatcher.transfer(recipient: constants::RECIPIENT(), amount: value), 'Should return true');

    // check balances
    assert(dispatcher.balance_of(constants::OWNER()) == constants::SUPPLY - value, 'Should equal SUPPLY - VALUE');
    assert(dispatcher.balance_of(constants::RECIPIENT()) == value, 'Should equal VALUE');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('1% Hodl limit reached', 'ENTRYPOINT_FAILED'))]
fn test_transfer_with_hodl_limit_above() {
    let mut dispatcher = setup_dispatcher();
    let value = constants::SUPPLY / 100 + 1; // 1% + 1

    // enable hodl limit
    dispatcher.enable_hodl_limit();

    // renounce ownership
    dispatcher.renounce_ownership();

    // transfer
    assert(dispatcher.transfer(recipient: constants::RECIPIENT(), amount: value), 'Should return true');
}

#[test]
#[available_gas(20000000)]
fn test_transfer_with_hodl_limit_above_from_owner() {
    let mut dispatcher = setup_dispatcher();
    let value = constants::SUPPLY / 100 + 1; // 1% + 1

    // enable hodl limit
    dispatcher.enable_hodl_limit();

    // transfer
    assert(dispatcher.transfer(recipient: constants::RECIPIENT(), amount: value), 'Should return true');

    // check balances
    assert(dispatcher.balance_of(constants::OWNER()) == constants::SUPPLY - value, 'Should equal SUPPLY - VALUE');
    assert(dispatcher.balance_of(constants::RECIPIENT()) == value, 'Should equal VALUE');
}

#[test]
#[available_gas(20000000)]
fn test_transfer_with_hodl_limit_above_to_pool() {
    let mut dispatcher = setup_dispatcher();
    let value = constants::SUPPLY / 100 + 1; // 1% + 1

    // enable hodl limit
    dispatcher.enable_hodl_limit();

    // add pool
    dispatcher.add_pool(constants::POOL());

    // renounce ownership
    dispatcher.renounce_ownership();

    // transfer
    assert(dispatcher.transfer(recipient: constants::POOL(), amount: value), 'Should return true');

    // check balances
    assert(dispatcher.balance_of(constants::OWNER()) == constants::SUPPLY - value, 'Should equal SUPPLY - VALUE');
    assert(dispatcher.balance_of(constants::POOL()) == value, 'Should equal VALUE');
}

//
// Transfer from
//

#[test]
#[available_gas(20000000)]
fn test_transfer_from() {
    let mut dispatcher = setup_dispatcher();

    // approve owner to spend on himself
    dispatcher.approve(spender: constants::OWNER(), amount: constants::SUPPLY);

    // transfer
    assert(
        dispatcher.transfer_from(
            sender: constants::OWNER(),
            recipient: constants::RECIPIENT(),
            amount: constants::VALUE
        ),
        'Should return true'
    );

    // check balances
    assert(
        dispatcher.balance_of(constants::OWNER()) == constants::SUPPLY - constants::VALUE,
        'Should equal SUPPLY - VALUE'
    );
    assert(
        dispatcher.balance_of(constants::RECIPIENT()) == constants::VALUE,
        'Should equal VALUE'
    );
}

#[test]
#[available_gas(20000000)]
fn test_transfer_from_with_hodl_limit() {
    let mut dispatcher = setup_dispatcher();
    let value = constants::SUPPLY / 100; // 1%

    // approve owner to spend on himself
    dispatcher.approve(spender: constants::OWNER(), amount: constants::SUPPLY);

    // enable hodl limit
    dispatcher.enable_hodl_limit();

    // renounce ownership
    dispatcher.renounce_ownership();

    // transfer
    assert(
        dispatcher.transfer_from(sender: constants::OWNER(), recipient: constants::RECIPIENT(), amount: value),
        'Should return true'
    );

    // check balances
    assert(dispatcher.balance_of(constants::OWNER()) == constants::SUPPLY - value, 'Should equal SUPPLY - VALUE');
    assert(dispatcher.balance_of(constants::RECIPIENT()) == value, 'Should equal VALUE');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('1% Hodl limit reached', 'ENTRYPOINT_FAILED'))]
fn test_transfer_from_with_hodl_limit_above() {
    let mut dispatcher = setup_dispatcher();
    let value = constants::SUPPLY / 100 + 1; // 1% + 1

    // approve owner to spend on himself
    dispatcher.approve(spender: constants::OWNER(), amount: constants::SUPPLY);

    // enable hodl limit
    dispatcher.enable_hodl_limit();

    // renounce ownership
    dispatcher.renounce_ownership();

    // transfer
    assert(
        dispatcher.transfer_from(sender: constants::OWNER(), recipient: constants::RECIPIENT(), amount: value),
        'Should return true'
    );
}

#[test]
#[available_gas(20000000)]
fn test_transfer_from_with_hodl_limit_above_from_owner() {
    let mut dispatcher = setup_dispatcher();
    let value = constants::SUPPLY / 100 + 1; // 1% + 1

    // approve owner to spend on himself
    dispatcher.approve(spender: constants::OWNER(), amount: constants::SUPPLY);

    // enable hodl limit
    dispatcher.enable_hodl_limit();

    // transfer
    assert(
        dispatcher.transfer_from(sender: constants::OWNER(), recipient: constants::RECIPIENT(), amount: value),
        'Should return true'
    );

    // check balances
    assert(dispatcher.balance_of(constants::OWNER()) == constants::SUPPLY - value, 'Should equal SUPPLY - VALUE');
    assert(dispatcher.balance_of(constants::RECIPIENT()) == value, 'Should equal VALUE');
}

#[test]
#[available_gas(20000000)]
fn test_transfer_from_with_hodl_limit_above_to_pool() {
    let mut dispatcher = setup_dispatcher();
    let value = constants::SUPPLY / 100 + 1; // 1% + 1

    // approve owner to spend on himself
    dispatcher.approve(spender: constants::OWNER(), amount: constants::SUPPLY);

    // enable hodl limit
    dispatcher.enable_hodl_limit();

    // add pool
    dispatcher.add_pool(constants::POOL());

    // renounce ownership
    dispatcher.renounce_ownership();

    // transfer
    assert(
        dispatcher.transfer_from(sender: constants::OWNER(), recipient: constants::POOL(), amount: value),
        'Should return true'
    );

    // check balances
    assert(dispatcher.balance_of(constants::OWNER()) == constants::SUPPLY - value, 'Should equal SUPPLY - VALUE');
    assert(dispatcher.balance_of(constants::POOL()) == value, 'Should equal VALUE');
}

//
// TransferFrom
//

#[test]
#[available_gas(20000000)]
fn test_transferFrom() {
    let mut dispatcher = setup_dispatcher();

    // approve owner to spend on himself
    dispatcher.approve(spender: constants::OWNER(), amount: constants::SUPPLY);

    // transfer
    assert(
        dispatcher.transferFrom(
            sender: constants::OWNER(),
            recipient: constants::RECIPIENT(),
            amount: constants::VALUE
        ),
        'Should return true'
    );

    // check balances
    assert(
        dispatcher.balance_of(constants::OWNER()) == constants::SUPPLY - constants::VALUE,
        'Should equal SUPPLY - VALUE'
    );
    assert(
        dispatcher.balance_of(constants::RECIPIENT()) == constants::VALUE,
        'Should equal VALUE'
    );
}

#[test]
#[available_gas(20000000)]
fn test_transferFrom_with_hodl_limit() {
    let mut dispatcher = setup_dispatcher();
    let value = constants::SUPPLY / 100; // 1%

    // approve owner to spend on himself
    dispatcher.approve(spender: constants::OWNER(), amount: constants::SUPPLY);

    // enable hodl limit
    dispatcher.enable_hodl_limit();

    // renounce ownership
    dispatcher.renounce_ownership();

    // transfer
    assert(
        dispatcher.transferFrom(sender: constants::OWNER(), recipient: constants::RECIPIENT(), amount: value),
        'Should return true'
    );

    // check balances
    assert(dispatcher.balance_of(constants::OWNER()) == constants::SUPPLY - value, 'Should equal SUPPLY - VALUE');
    assert(dispatcher.balance_of(constants::RECIPIENT()) == value, 'Should equal VALUE');
}

#[test]
#[available_gas(20000000)]
#[should_panic(expected: ('1% Hodl limit reached', 'ENTRYPOINT_FAILED'))]
fn test_transferFrom_with_hodl_limit_above() {
    let mut dispatcher = setup_dispatcher();
    let value = constants::SUPPLY / 100 + 1; // 1% + 1

    // approve owner to spend on himself
    dispatcher.approve(spender: constants::OWNER(), amount: constants::SUPPLY);

    // enable hodl limit
    dispatcher.enable_hodl_limit();

    // renounce ownership
    dispatcher.renounce_ownership();

    // transfer
    assert(
        dispatcher.transferFrom(sender: constants::OWNER(), recipient: constants::RECIPIENT(), amount: value),
        'Should return true'
    );
}

#[test]
#[available_gas(20000000)]
fn test_transferFrom_with_hodl_limit_above_from_owner() {
    let mut dispatcher = setup_dispatcher();
    let value = constants::SUPPLY / 100 + 1; // 1% + 1

    // approve owner to spend on himself
    dispatcher.approve(spender: constants::OWNER(), amount: constants::SUPPLY);

    // enable hodl limit
    dispatcher.enable_hodl_limit();

    // transfer
    assert(
        dispatcher.transferFrom(sender: constants::OWNER(), recipient: constants::RECIPIENT(), amount: value),
        'Should return true'
    );

    // check balances
    assert(dispatcher.balance_of(constants::OWNER()) == constants::SUPPLY - value, 'Should equal SUPPLY - VALUE');
    assert(dispatcher.balance_of(constants::RECIPIENT()) == value, 'Should equal VALUE');
}

#[test]
#[available_gas(20000000)]
fn test_transferFrom_with_hodl_limit_above_to_pool() {
    let mut dispatcher = setup_dispatcher();
    let value = constants::SUPPLY / 100 + 1; // 1% + 1

    // approve owner to spend on himself
    dispatcher.approve(spender: constants::OWNER(), amount: constants::SUPPLY);

    // enable hodl limit
    dispatcher.enable_hodl_limit();

    // add pool
    dispatcher.add_pool(constants::POOL());

    // renounce ownership
    dispatcher.renounce_ownership();

    // transfer
    assert(
        dispatcher.transferFrom(sender: constants::OWNER(), recipient: constants::POOL(), amount: value),
        'Should return true'
    );

    // check balances
    assert(dispatcher.balance_of(constants::OWNER()) == constants::SUPPLY - value, 'Should equal SUPPLY - VALUE');
    assert(dispatcher.balance_of(constants::POOL()) == value, 'Should equal VALUE');
}

//
// Helpers
//

fn assert_event_transfer(contract: ContractAddress, from: ContractAddress, to: ContractAddress, value: u256) {
    let event = utils::pop_log::<Transfer>(contract).unwrap();
    assert(event.from == from, 'Invalid `from`');
    assert(event.to == to, 'Invalid `to`');
    assert(event.value == value, 'Invalid `value`');

    // Check indexed keys
    let mut indexed_keys = array![];
    indexed_keys.append_serde(from);
    indexed_keys.append_serde(to);
    utils::assert_indexed_keys(event, indexed_keys.span());
}

fn assert_event_ownership_transferred(
    contract: ContractAddress,
    previous_owner: ContractAddress,
    new_owner: ContractAddress
) {
    let event = utils::pop_log::<OwnershipTransferred>(contract).unwrap();
    assert(event.previous_owner == previous_owner, 'Invalid `previous_owner`');
    assert(event.new_owner == new_owner, 'Invalid `new_owner`');
}
