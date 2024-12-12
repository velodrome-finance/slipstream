# Fee Modules

## Dynamic Swap Fee Module

A fee module that adjusts slipstream fees based on the recent volatility of the pool.

The formula is as follows:

$f = min(f_{base} + f_{dynamic}, f_{cap})$

$f_{dynamic} = K \times \vert t-TWAVG(tick) \space \vert$

where:
- $f_{base}$ is the base fee for the pool, paid on all swaps
- $K$ is the scaling factor for the pool, which scales the dynamic fee
- $tick$ is the current tick of the pool
- $TWAVG(tick)$ is the time-weighted average tick of the pool
- $f_{cap}$ is the cap for the total fee (i.e. the maximum fee that can be charged)

The rationale for this formula is to increase the fee when the tick is moving away from the 
TWAVG(tick) and decrease the fee when the tick is moving towards the TWAVG(tick).

Dynamic fee module parameters are configurable on a per pool basis by the swap fee manager. If they
are not configured, the default values will be used. The default parameters are also mutable. It is
possible to set up the dynamic fee module such that it is only using the base fee. 

The parameters that are configurable are:
- $f_{base}$, the base fee for the pool
- $K$, the scaling factor for the fee
- $f_{cap}$, the cap for the total fee
- `defaultFeeCap`, the default cap for the total fee
- `defaultScalingFactor`, the default scaling factor for the fee
- `secondsAgo`, the number of seconds to look back when calculating the TWAVG(tick)

Given that there is a dependency on oracle observations, the dynamic fee module will not be active
until the pool is set up such that it:
- is able to store sufficient observations for the `secondsAgo` parameter (requires increasing 
observation cardinality)
- has sufficient observations to calculate the TWAVG(tick)

### Fee Discounts

There is support for fee discounts. Swaps made by discounted addresses will have their fee reduced.
- Discounted swaps are identified by the `tx.origin` of the caller. 
- Discounts are configured on a per pool basis by the swap fee manager. 
- The discount is applied to the total fee.