%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.starknet.common.storage import Storage
from starkware.cairo.common.math import assert_lt
from starkware.starknet.common import syscall_ptr
from starkware.starknet.common import call_contract

from Initializable import initialized, _initialize

struct Message:
    to: felt
    selector: felt
    calldata: felt
    calldata_size: felt
    new_nonce: felt
end

struct SignedMessage:
    message: Message
    sig_r: felt
    sig_s: felt
end

@storage_var
func nonce() -> (res: felt):
end

@storage_var
func public_key() -> (res: felt):
end

@storage_var
func initialized() -> (res: felt):
end

@external
func initialize{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin* } (_public_key: felt):
    let _initialized = initialized.read()
    assert_lt(_initialized, 1)
    initialized.write(1)
    public_key.write(_public_key)
    return ()
end

@view
func validate{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin*, range_check_ptr }
    (signed_message: SignedMessage):

    let message = signed_message.message
    let public_key = public_key.read()

    # verify signature
    verify_ecdsa_signature(
        # to do: this should be a felt, not a struct
        message=message,
        public_key=public_key,
        signature_r=signed_message.sig_r,
        signature_s=signed_message.sig_s)

    # validate nonce
    # todo: decide between any larger nonce or strict +1
    let current_nonce = nonce.read()
    assert_lt(current_nonce, message.new_nonce)

    return ()
end

@external
func execute{ storage_ptr: Storage*, pedersen_ptr: HashBuiltin*, range_check_ptr, syscall_ptr }
    (signed_message: SignedMessage) -> (response_size : felt, response : felt*):

    let message = signed_message.message

    # validate transaction
    validate(signed_message)

    # update nonce
    nonce.write(message.new_nonce)

    # execute call
    let response = call_contract(
        contract_address=message.to,
        function_selector=message.selector,
        calldata_size=message.calldata_size,
        calldata=message.calldata
    )

    return (response=response.retdata, response_size=response.retdata_size)
end