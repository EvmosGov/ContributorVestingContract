// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./storage/VestingData.sol";

/**
 * @title EvmosVesting
 * @dev An Evmos holding contract that can release its balance gradually like a
 * typical vesting scheme, with a vesting period. Optionally revocable by the
 * owner, or in our case a community controlled multisig safe.
 * NOTE: anyone can send EVMOS to the contract but only the owner of the contract or the beneficiary can receive EVMOS from this contract.
 * TODO: Create factory contract for easier deployment of vesting contracts.
 * TODO: Allow the vesting contract to handle ERC20 deposits.
 */
contract EvmosVesting is Ownable, ReentrancyGuard, VestingData {
    // The vesting schedule is time-based (i.e. using block timestamps as opposed to e.g. block numbers). In Ethereum
    // pre-merge, short vesting times (minutes or even hours) were somewhat susceptible to timestamp manipulation by miners.
    // This is no longer relevant, and long vesting periods - for example, 4 years as I proposed - are not susceptible to this manipulation. 
    // Refer to OpenZeppelin documentation regarding the access control Ownable.sol and the ReentrancyGuard contract. 
    // solhint-disable not-rely-on-time

    using SafeMath for uint256;

    event LogReleased(uint256 amount);
    event LogRevoked(bool releaseSuccessful);

    // Beneficiary of the EVMOS vesting contract.
    address private _beneficiary;

    // Durations and timestamps are expressed in UNIX time, the same units as block.timestamp.
    uint256 private _start;
    uint256 private _duration;

    // Set to true when initializing the contract for DAO contributors unless in 
    // special cases where governance has allowed an unrevocable contract.
    bool private _revocable;

    uint256 private _released;
    bool private _revoked;

    /**
     * @dev Creates the contract that vests its balance of EVMOS to the
     * beneficiary, linearly from start time + duration of the overall vesting period. 
     * @param beneficiary address of the beneficiary to whom vested Evmos is transferred
     * @param start the time (as Unix time) at which point vesting starts
     * @param duration duration in seconds of the period in which the Evmos will vest
     * @param revocable whether the vesting is revocable or not
     */
    constructor (address beneficiary, uint256 start, uint256 duration, bool revocable) {
        require(beneficiary != address(0), "EvmosVesting: beneficiary is the zero address");
        // solhint-disable-next-line max-line-length
        require(duration > 0, "EvmosVesting: duration is 0");
        // solhint-disable-next-line max-line-length
        require(start.add(duration) > block.timestamp, "EvmosVesting: final time is before current time");

        _beneficiary = beneficiary;
        _revocable = revocable;
        _duration = duration;
        _start = start;
    }

    /**
     * @return the beneficiary of the Evmos.
     */
    function beneficiary() public view returns (address) {
        return _beneficiary;
    }

    /**
     * @return the start time of the Evmos vesting.
     */
    function start() public view returns (uint256) {
        return _start;
    }

    /**
     * @return the duration of the Evmos vesting.
     */
    function duration() public view returns (uint256) {
        return _duration;
    }

    /**
     * @return true if the vesting is revocable.
     */
    function revocable() public view returns (bool) {
        return _revocable;
    }

    /**
     * @return the amount of the Evmos released.
     */
    function released() public view returns (uint256) {
        return _released;
    }

    /**
     * @return true if the Evmos is revoked.
     */
    function revoked() public view returns (bool) {
        return _revoked;
    }

    /**
     * @notice Transfers vested Evmos to beneficiary.
     */
    function release()
        external
        nonReentrant
    {
        uint256 unreleased = _releasableAmount();

        require(unreleased > 0, "EvmosVesting: no Evmos are due");

        _released = _released.add(unreleased);


        (bool success, ) = _beneficiary.call{ value: unreleased}("");
        require(
            success,
            "EvmosVesting::Transfer Error. Unable to send unreleased to _beneficiary."
        );

        emit LogReleased(unreleased);
    }

    /**
     * @notice Allows the owner (multisig or treasury) to revoke the vesting. Evmos already vested
     * remain in the contract, the rest are returned to the owner.
     * @TODO - Create function to allow partial revokes for negative adjustments.
     */
    function revoke()
        external
        onlyOwner
        nonReentrant
    {
        require(_revocable, "EvmosVesting: cannot revoke");
        require(!_revoked, "EvmosVesting: EVMOS already revoked");


        uint256 unreleased = _releasableAmount();

        (bool releaseSuccessful, ) = _beneficiary.call{ value: unreleased }("");
        if (releaseSuccessful) {
            _released = _released.add(unreleased);
            emit LogReleased(unreleased);
        }

        uint256 refund = address(this).balance;

        _revoked = true;

        if (refund > 0) {
            (bool success, ) = owner().call{ value: refund}("");
            require(
                success,
                "EvmosVesting::Transfer Error. Unable to send refund to owner."
            );
        }

        emit LogRevoked(releaseSuccessful);
    }

    /**
     * @dev Calculates the amount that has already vested but hasn't been released yet.
     */
    function _releasableAmount() private view returns (uint256) {
        return _vestedAmount().sub(_released);
    }

    /**
     * @dev Calculates the amount that has already vested.
     */
    function _vestedAmount() private view returns (uint256) {
        if (block.timestamp <= _start) return 0;

        uint256 currentBalance = address(this).balance;
        uint256 totalBalance = currentBalance.add(_released);

        if (block.timestamp >= _start.add(_duration) || _revoked) {
            return totalBalance;
        } else {
            return totalBalance.mul(block.timestamp.sub(_start)).div(_duration);
        }
    }


    /**
     * @dev For when more Evmos is received by the contract. Most likely to be sent from a multisig after 
     * each funding cycle adjustments or as bonus. Does NOT have to be sent by the contract owner, but ONLY the owner
     * can recover revoked funds.
     */
    receive()
        external
        payable
        nonReentrant
    {

        require(
            msg.value > 0,
            "fallback::Invalid Value. msg.value must be greater than 0."
        );

        increaseTotalFundingBy(msg.value);

        emit LogFunding(msg.sender, msg.value);
    }
}