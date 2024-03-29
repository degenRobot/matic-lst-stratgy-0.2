// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console.sol";
import {Setup, ERC20, IStrategyInterface} from "./utils/Setup.sol";

contract OperationTest is Setup {
    function setUp() public virtual override {
        super.setUp();
    }

    function test_setupStrategyOK() public {
        console.log("address of strategy", address(strategy));
        assertTrue(address(0) != address(strategy));
        assertEq(strategy.asset(), address(asset));
        assertEq(strategy.management(), management);
        assertEq(strategy.performanceFeeRecipient(), performanceFeeRecipient);
        assertEq(strategy.keeper(), keeper);
        // TODO: add additional check on strat params
    }

    function test_operation(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        console.log(strategy.getOraclePriceLst());

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        // TODO: Implement logic so totalDebt is _amount and totalIdle = 0.
        assertEq(strategy.totalAssets(), _amount, "!totalAssets");
        //assertEq(strategy.totalDebt(), _amount, "!totalDebt");
        //assertEq(strategy.totalIdle(), 0, "!totalIdle");

        // Earn Interest
        skip(1 days);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGe(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        console.log('total assets', strategy.totalAssets());
        console.log('balance lp ', strategy.balanceLp());
        console.log('balance lend ', strategy.balanceLend());
        console.log('balance debt ', strategy.balanceDebt());

        console.log('wMatic Balance ', wMatic.balanceOf(address(strategy)));
        console.log('stMatic Balance ', stMatic.balanceOf(address(strategy)));

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertApproxEq(
            asset.balanceOf(user),
            balanceBefore + _amount,
            _amount / 1000,
            "!final balance"
        );
    }

    function test_profitableReport(
        uint256 _amount,
        uint16 _profitFactor
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS));

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        // TODO: Implement logic so totalDebt is _amount and totalIdle = 0.
        assertEq(strategy.totalAssets(), _amount, "!totalAssets");
        //assertEq(strategy.totalDebt(), _amount, "!totalDebt");
        //assertEq(strategy.totalIdle(), 0, "!totalIdle");

        // Earn Interest
        skip(1 days);

        // TODO: implement logic to simulate earning interest.

        uint256 toAirdrop = (_amount * _profitFactor) / MAX_BPS;

        uint256 airdropAmt = (toAirdrop * MAX_BPS / rewardPrice) * (1e12);

        airdrop(rewardToken, address(strategy), airdropAmt);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        console.log('profit', profit);
        console.log('expected profit', toAirdrop);

        // Check return Values
        assertGe(profit, toAirdrop, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );
    }

    function test_profitableReport_withFees(
        uint256 _amount,
        uint16 _profitFactor
    ) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);
        _profitFactor = uint16(bound(uint256(_profitFactor), 10, MAX_BPS));

        // Set protocol fee to 0 and perf fee to 10%
        setFees(0, 1_000);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        // TODO: Implement logic so totalDebt is _amount and totalIdle = 0.
        assertEq(strategy.totalAssets(), _amount, "!totalAssets");
        //assertEq(strategy.totalDebt(), _amount, "!totalDebt");
        //assertEq(strategy.totalIdle(), 0, "!totalIdle");

        // Earn Interest
        skip(1 days);

        // TODO: implement logic to simulate earning interest.
        uint256 toAirdrop = (_amount * _profitFactor) / MAX_BPS;
        uint256 airdropAmt = (toAirdrop * MAX_BPS / rewardPrice) * (1e12);

        airdrop(rewardToken, address(strategy), airdropAmt);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        console.log('profit', profit);
        console.log('expected profit', toAirdrop);

        // Check return Values
        assertGe(profit, toAirdrop, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        // Get the expected fee
        uint256 expectedShares = (profit * 1_000) / MAX_BPS;

        assertEq(strategy.balanceOf(performanceFeeRecipient), expectedShares);

        uint256 balanceBefore = asset.balanceOf(user);

        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertGe(
            asset.balanceOf(user),
            balanceBefore + _amount,
            "!final balance"
        );

        vm.prank(performanceFeeRecipient);
        strategy.redeem(
            expectedShares,
            performanceFeeRecipient,
            performanceFeeRecipient
        );

        checkStrategyTotals(strategy, 0, 0, 0);

        assertGe(
            asset.balanceOf(performanceFeeRecipient),
            expectedShares,
            "!perf fee out"
        );
    }

    function test_collateral_rebalance(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        console.log(strategy.getOraclePriceLst());

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        // TODO: Implement logic so totalDebt is _amount and totalIdle = 0.
        assertEq(strategy.totalAssets(), _amount, "!totalAssets");
        //assertEq(strategy.totalDebt(), _amount, "!totalDebt");
        //assertEq(strategy.totalIdle(), 0, "!totalIdle");

        assertApproxEq(strategy.calcCollateralRatio(), strategy.collatTarget(), 100, "!collatRatio");


        // Earn Interest
        skip(1 days);

        // Report profit
        vm.prank(keeper);
        (uint256 profit, uint256 loss) = strategy.report();

        // Check return Values
        assertGe(profit, 0, "!profit");
        assertEq(loss, 0, "!loss");

        skip(strategy.profitMaxUnlockTime());

        uint256 balanceBefore = asset.balanceOf(user);


        // We drop collateral ratios then check rebalances works as intended 
        vm.prank(management);
        strategy.setCollatTargets(3500, 4000, 4500);

        assertEq(strategy.collatLower(), 3500, "!collatLow");
        assertEq(strategy.collatTarget(), 4000, "!collatTarget");
        assertEq(strategy.collatUpper(), 4500, "!collatUpper");

        vm.prank(keeper);
        strategy.rebalanceCollateral();

        // margin of error for collateral ratio after rebalance vs target c ratio
        uint256 collatMarginOfError = 500;

        assertApproxEq(strategy.calcCollateralRatio(), strategy.collatTarget(), collatMarginOfError, "!collatRatioLow");


        // Increase collateral ratios then check rebalances work as intended 
        vm.prank(management);
        strategy.setCollatTargets(4500, 5000, 5500);

        assertEq(strategy.collatLower(), 4500, "!collatLow");
        assertEq(strategy.collatTarget(), 5000, "!collatTarget");
        assertEq(strategy.collatUpper(), 5500, "!collatUpper");

        vm.prank(keeper);
        strategy.rebalanceCollateral();

        assertApproxEq(strategy.calcCollateralRatio(), strategy.collatTarget(), collatMarginOfError, "!collatRatioHigh");


        // Withdraw all funds
        vm.prank(user);
        strategy.redeem(_amount, user, user);

        assertApproxEq(
            asset.balanceOf(user),
            balanceBefore + _amount,
            _amount / 1000,
            "!final balance"
        );
    }    

    /*
    function test_tendTrigger(uint256 _amount) public {
        vm.assume(_amount > minFuzzAmount && _amount < maxFuzzAmount);

        (bool trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);

        // Deposit into strategy
        mintAndDepositIntoStrategy(strategy, user, _amount);

        (trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);

        // Skip some time
        skip(1 days);

        (trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);

        vm.prank(keeper);
        strategy.report();

        (trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);

        // Unlock Profits
        skip(strategy.profitMaxUnlockTime());

        (trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);

        vm.prank(user);
        strategy.redeem(_amount, user, user);

        (trigger, ) = strategy.tendTrigger();
        assertTrue(!trigger);
    }
    */
}
