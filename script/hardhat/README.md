# Hardhat Deployment Instructions

Hardhat support provided as a way to easily deploy and verify contracts on Tenderly.
This deployment assumes an existing Velodrome deployment exists. 

## Set Up

1. Create a new fork on Tenderly. Once you have the fork, copy the fork id number (the component after `/fork`/ in the URL) and set it as your `TENDERLY_FORK_ID` in the `.env` file. The other fields that must be set include `PRIVATE_KEY_DEPLOY`, set to a private key used for testing.
2. Install packages via `npm install` or `yarn install`.
3. Follow the instructions of the [tenderly hardhat package](https://github.com/Tenderly/hardhat-tenderly/tree/master/packages/tenderly-hardhat) to install the tenderly cli and login.

## Deployment

1. Run the script

```
npx hardhat run script/hardhat/DeployCL.ts --network tenderly
```