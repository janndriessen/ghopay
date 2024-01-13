// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {
    GelatoRelayContext
} from "@gelatonetwork/relay-context/contracts/GelatoRelayContext.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract PaymentSettlement is GelatoRelayContext, EIP712, Ownable, Pausable {

    using SafeERC20 for IERC20;

    bytes32 public constant PAY_TYPEHASH =
        keccak256("Pay(address receiver,uint256 permitNonce)");

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
    struct PermitData {
        uint256 deadline;
        Signature signature;
    }

    struct PaymentData {
        address token;
        address from;
        address to;
        uint256 amount;
        PermitData permitData;
    }

    event Payment(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 amount
    );

    constructor() EIP712("PaymentSettlement", "1") {}

    function pay(
        PaymentData calldata _paymentData,
        Signature calldata _signature
    ) external whenNotPaused onlyGelatoRelay {

        require(_verifySignature(_paymentData, _signature), "PaymentSettlement: invalid signature");

        IERC20Permit(_paymentData.token).permit(
            _paymentData.from,
            address(this),
            _paymentData.amount,
            _paymentData.permitData.deadline,
            _paymentData.permitData.signature.v,
            _paymentData.permitData.signature.r,
            _paymentData.permitData.signature.s
        );

        IERC20(_paymentData.token).safeTransferFrom(
            _paymentData.from,
            address(this),
            _paymentData.amount
        );

        _transferRelayFee();

        SafeERC20.safeTransfer(
            IERC20(_paymentData.token),
            _paymentData.to,
            IERC20(_paymentData.token).balanceOf(address(this))
        );

        emit Payment(
            _paymentData.token,
            _paymentData.from,
            _paymentData.to,
            _paymentData.amount
        );

    }

    // This function is used to verify the data and revert the transaction
    // Only call as static call to avoid wasting gas
    function verifyData(
        PaymentData calldata _paymentData,
        Signature calldata _signature
    ) external whenNotPaused returns (bool) {

        try this.verifyDataReverting(_paymentData, _signature) {
            revert("PaymentSettlement: verifyDataReverting did not revert");
        } catch Error(string memory reason) {
            // Check that the right error was thrown
            if (keccak256(abi.encodePacked(reason)) != keccak256(abi.encodePacked("PaymentSettlement: verification complete"))) {
                return(false);
            }
        } catch {
           return (false);
        }

        return(true);
    }

    // This function is used to verify the data and revert the transaction
    // This will always revert and is only meant to be called by verifyData
    function verifyDataReverting(
        PaymentData calldata _paymentData,
        Signature calldata _signature
    ) external {

        require(_verifySignature(_paymentData, _signature), "PaymentSettlement: invalid signature");

        IERC20Permit(_paymentData.token).permit(
            _paymentData.from,
            address(this),
            _paymentData.amount,
            _paymentData.permitData.deadline,
            _paymentData.permitData.signature.v,
            _paymentData.permitData.signature.r,
            _paymentData.permitData.signature.s
        );

        IERC20(_paymentData.token).safeTransferFrom(
            _paymentData.from,
            address(this),
            _paymentData.amount
        );

        SafeERC20.safeTransfer(
            IERC20(_paymentData.token),
            _paymentData.to,
            IERC20(_paymentData.token).balanceOf(address(this))
        );

        revert("PaymentSettlement: verification complete");

    }


    function verifySignature(
        PaymentData calldata _paymentData,
        Signature calldata _signature
    ) external view returns (bool) {
        bool result = _verifySignature(_paymentData, _signature);
        return result;
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function transferOwner(address _newOwner) external onlyOwner {
        _transferOwnership(_newOwner);
    }

    // ====== INTERNAL FUNCTIONS ======

    function _verifySignature(
        PaymentData calldata _paymentData,
        Signature calldata _signature
    ) internal view  returns(bool) {
        uint256 userNonce = IERC20Permit(_paymentData.token).nonces(_paymentData.from);

        bytes32 paymentStructHash = keccak256(abi.encode(
            PAY_TYPEHASH,
            _paymentData.to,
            userNonce
        ));
        bytes32 hash = _hashTypedDataV4(paymentStructHash);
        address signer = ECDSA.recover(hash, _signature.v, _signature.r, _signature.s);
        bool result = signer == _paymentData.from;
        return(result);
    }

}