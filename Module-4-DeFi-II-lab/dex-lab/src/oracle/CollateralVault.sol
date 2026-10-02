// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import {IPriceOracle} from "./IPriceOracle.sol";
import {IERC20} from "../interfaces/IERC20.sol";

/// @title CollateralVault — a minimal collateralised lending pool.
/// @notice Users deposit a collateral token and borrow a stable token against it, up to
/// a loan-to-value fraction of the collateral's oracle-reported value. The vault is
/// deliberately simple: no interest, no liquidations, one position per user. Its single
/// security-critical dependency is the price oracle, which is why it takes the oracle as
/// a constructor argument — the same vault code is wired to the spot oracle to be
/// exploited, then to the TWAP oracle to be defended.
contract CollateralVault {
    IERC20 public immutable collateral;
    IERC20 public immutable stable;
    IPriceOracle public immutable oracle;
    uint256 public immutable ltvBps; // loan-to-value in basis points (e.g. 5000 = 50%)

    mapping(address => uint256) public collateralOf;
    mapping(address => uint256) public debtOf;

    constructor(address _collateral, address _stable, address _oracle, uint256 _ltvBps) {
        collateral = IERC20(_collateral);
        stable = IERC20(_stable);
        oracle = IPriceOracle(_oracle);
        ltvBps = _ltvBps;
    }

    /// @notice Stable liquidity available to borrowers (funded by the protocol/LPs).
    function fund(uint256 amount) external {
        require(stable.transferFrom(msg.sender, address(this), amount), "Vault: FUND_FAILED");
    }

    function deposit(uint256 amount) external {
        require(collateral.transferFrom(msg.sender, address(this), amount), "Vault: DEPOSIT_FAILED");
        collateralOf[msg.sender] += amount;
    }

    /// @notice The most a user may owe: the oracle value of their collateral times LTV.
    function maxBorrow(address user) public view returns (uint256) {
        uint256 collValue = oracle.consult(address(collateral), collateralOf[user]);
        return collValue * ltvBps / 10_000;
    }

    /// @notice Borrow `amount` of stable. The only defence against bad debt is the oracle
    /// value used here; if the oracle can be manipulated, so can this check.
    function borrow(uint256 amount) external {
        require(debtOf[msg.sender] + amount <= maxBorrow(msg.sender), "Vault: UNDERCOLLATERALISED");
        debtOf[msg.sender] += amount;
        require(stable.transfer(msg.sender, amount), "Vault: BORROW_FAILED");
    }

    function repay(uint256 amount) external {
        require(stable.transferFrom(msg.sender, address(this), amount), "Vault: REPAY_FAILED");
        debtOf[msg.sender] -= amount;
    }
}
