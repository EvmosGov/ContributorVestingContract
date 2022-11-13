// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IVestingData.sol";

/**
 * @title Vesting Contract Data.
 * @dev Handles state for tracking contract total amount funded for vesting contract.
 */
abstract contract VestingData is IVestingData {
    using SafeMath for uint256;


    /*----------  Globals and Setters/Getters  ----------*/

    /* solhint-disable max-line-length */
    uint256 private totalFunding;
    /* solhint-enable max-line-length */

    /**
     * @dev Cumulative funding of the vesting contract by Evmos Community.
     */
    function getTotalFunding()
        public
        override
        view
        returns(uint256)
    {
        return totalFunding;
    }

    /**
     * @dev Increase cumulative funding for vesting contract.
     * @param value amount to increase total token vesting by.
     */
    function increaseTotalFundingBy(uint256 value)
        internal
    {
        totalFunding = totalFunding.add(value);
    }

    function setTotalFunding(uint256 value)
        internal
    {
        totalFunding = value;
    }

}