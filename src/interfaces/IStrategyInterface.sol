// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.18;

import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";

interface IStrategyInterface is IStrategy {
    //TODO: Add your specific implementation interface in here.
    function getOraclePriceLst() external view returns (uint256);
    function balanceLp() external view returns (uint256);
    function balanceDebt() external view returns (uint256);
    function balanceLend() external view returns (uint256);
    function setCollatTargets(uint256 _collatLow, uint256 _collatTarget, uint256 _collatHigh) external;
    function calcCollateralRatio() external view returns(uint256);
    function rebalanceCollateral() external;
    function collatTarget() external view returns (uint256);
    function collatLower() external view returns (uint256);
    function collatUpper() external view returns (uint256);
}
