// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title LinearVestingVault
 * @dev A token vesting contract that will release tokens gradually like a standard
 * equity vesting schedule, with a cliff and vesting period but no arbitrary restrictions
 * on the frequency of claims. Optionally has an initial tranche claimable immediately
 * after the cliff expires.
 */
contract LinearVestingVault is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    event Issued(
        address beneficiary,
        uint256 amount,
        uint256 start,
        uint256 cliff,
        uint256 duration
    );

    event Released(address beneficiary, uint256 amount, uint256 remaining);
    event Revoked(address beneficiary, uint256 allocationAmount, uint256 revokedAmount);

    struct Allocation {
        uint256 start;
        uint256 cliff;
        uint256 duration;
        uint256 total;
        uint256 claimed;
        uint256 initial;
    }

    ERC20 public token;
    mapping(address => Allocation[]) public allocations;

    /**
     * @dev Creates a vesting contract that releases allocations of an ERC20 token over time.
     * @param _token ERC20 token to be vested
     */
    constructor(ERC20 _token) {
        token = _token;
    }

    /**
     * @dev Creates a new allocation for a beneficiary. Tokens are released linearly over
     * time until a given number of seconds have passed since the start of the vesting
     * schedule.
     * @param _beneficiary address to which tokens will be released
     * @param _amount uint256 amount of the allocation (in wei)
     * @param _startAt uint256 the unix timestamp at which the vesting may begin
     * @param _cliff uint256 the number of seconds after _startAt before which no vesting occurs
     * @param _duration uint256 the number of seconds after which the entire allocation is vested
     * @param _initialPct uint256 percentage of the allocation initially available (integer, 0-100)
     */
    function issue(
        address _beneficiary,
        uint256 _amount,
        uint256 _startAt,
        uint256 _cliff,
        uint256 _duration,
        uint256 _initialPct
    ) public onlyOwner {
        require(token.allowance(msg.sender, address(this)) >= _amount, "Token allowance not sufficient");
        require(_beneficiary != address(0), "Cannot grant tokens to the zero address");
        require(_cliff <= _duration, "Cliff must not exceed duration");
        require(_initialPct <= 100, "Initial release percentage must be an integer 0 to 100 (inclusive)");

        token.safeTransferFrom(msg.sender, address(this), _amount);
        Allocation memory allocation;

        allocation.total = _amount;
        allocation.start = _startAt;
        allocation.cliff = _cliff;
        allocation.duration = _duration;
        
        allocation.initial = _amount.mul(_initialPct).div(100);
        allocations[_beneficiary].push(allocation);
        emit Issued(_beneficiary, _amount, _startAt, _cliff, _duration);
    }
    
    /**
     * @dev Revokes an existing allocation. Any vested tokens are transferred
     * to the beneficiary and the remainder are returned to the contract's owner.
     * @param _beneficiary The address whose allocation is to be revoked
     */
    function revoke(
        address _beneficiary
    ) public onlyOwner {
        uint256 total;
        uint256 remainder;
        for (uint8 i = 0; i < allocations[_beneficiary].length; i++) {
            total += allocations[_beneficiary][i].total;
            remainder = total-allocations[_beneficiary][i].claimed;
        }

        delete allocations[_beneficiary];
        
        token.safeTransfer(msg.sender, remainder);
        emit Revoked(
            _beneficiary,
            total,
            remainder
        );
    }

    /**
     * @dev Transfers vested tokens to a given beneficiary. Callable by anyone.
     * @param beneficiary address which is being vested
     */
    function release(address beneficiary) public {

        for (uint8 i = 0; i < allocations[beneficiary].length; i++) {
            uint256 amount = _releasableAmount(allocations[beneficiary][i]);
            allocations[beneficiary][i].claimed += amount;
            token.safeTransfer(beneficiary, amount);
            emit Released(
                beneficiary,
                amount,
                allocations[beneficiary][i].total.sub(allocations[beneficiary][i].claimed)
            );
        }
    }
    
    /**
     * @dev Calculates the amount that has already vested but has not been
     * released yet for a given address.
     * @param beneficiary Address to check
     */
    function releasableAmount(address beneficiary)
        public
        view
        returns (uint256)
    {
        uint256 amount;
        for (uint8 i = 0; i < allocations[beneficiary].length; i++) {
            amount += _releasableAmount(allocations[beneficiary][i]);
        }
        return amount;
    }

    /**
     * @dev Calculates the amount that has already vested but hasn't been released yet.
     * @param allocation Allocation to calculate against
     */
    function _releasableAmount(Allocation storage allocation)
        internal
        view
        returns (uint256)
    {
        return _vestedAmount(allocation).sub(allocation.claimed);
    }

    /**
     * @dev Calculates the amount that has already vested.
     * @param allocation Allocation to calculate against
     */
    function _vestedAmount(Allocation storage allocation)
        internal
        view
        returns (uint256 amount)
    {
        if (block.timestamp < allocation.start.add(allocation.cliff)) {
            amount = 0;
        } else if (block.timestamp >= allocation.start.add(allocation.duration)) {
            // if the entire duration has elapsed, everything is vested
            amount = allocation.total;
        } else {
            // the "initial" amount is available once the cliff expires, plus the
            // proportion of tokens vested as of the current block's timestamp
            amount = allocation.initial.add(
                allocation.total
                    .sub(allocation.initial)
                    .sub(amount)
                    .mul(block.timestamp.sub(allocation.start))
                    .div(allocation.duration)
            );
        }
        
        return amount;
    }
}