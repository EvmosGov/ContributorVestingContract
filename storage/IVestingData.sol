// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

/**
 * @title Vesting Contract Spec Abstract.
 */
interface IVestingData {

    /*----------  Events  ----------*/

    /**
     * @dev Funding target reached event.
     */
    event LogFundingComplete();

    /**
     * @dev Vesting contract received funding from an address. 
     * @param donor Address funding the vesting contract.
     * @param value Amount in WEI. 
     */
    event LogFunding(address indexed donor, uint256 value);


    /*----------  Shared Getters  ----------*/

    /**
     * @dev Cumulative funding sent to vesting contract.
     */
    function getTotalFunding()
        external
        view
        returns(uint256);


}