# Title: Weather NFT

## Protocol About

proceess:
    - minting []
    - update weather (checking with checkUpkeep() first) [performUpkeep() --> _sendFunctionsWeatherFetchRequest() --> _sendRequest() --> [[Chainlink Function Oracle]] --> fulfillRequest()]


## Roles:

## Audit Scope

## Project Stats

## Compatibilities
- Solc versions:
- Chains for production:
- Tokens:

## Known Issues

--------------------------------------------------------------------

# LISTS:

## Restrictions:
## Unknows:
identified by pincode and ISO country code
basis of heartbeat

## Invariants

### Not Testeables Invariants:

### Confirmed Invariants

### Not Confirmed Invariants
User can mint weather NFT by paying the mint price
Mint price increases with each mint

----------------------------------------------------------------------

# Audit Process

### 1. (+) Onboarding
### 2. (+) Research unknows
### 3. (+) Search restrictions
### 4. (+) Automated analisis
### 5. (+) Increase Kwnoledge
### 6. (+) Search the invariants
### 6. (-) Manual analisis
### 7. (-) Fuzzing
### 8. (-) Answering
### 9. (-) Analisis-Answer loop
### 10. (-) Reporting

----------------------------------------------------------------------

# Auxiliary Notes

// @? - this is relevant
```text
@ethersproject/providers  <=5.7.2
Depends on vulnerable versions of ws
node_modules/eth-crypto/node_modules/@ethersproject/providers
node_modules/zksync-ethers/node_modules/@ethersproject/providers
@trufflesuite/uws-js-unofficial  *
Depends on vulnerable versions of ws
node_modules/ganache/node_modules/@trufflesuite/uws-js-unofficial
```