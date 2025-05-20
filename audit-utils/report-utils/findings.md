### [S-#] TITLE (Root Cause + Impact)

**Description:**\

**Impact:**\

**Proof of Concept:**\

**Recommended Mitigation:**\


## High

## Medium

## Low

### [L-#] Missing diff between rain and drizzle weather conditions giving a not accurate weather info

**Description:**\
The `GetWeather.js` code treat rain and drizzle weather conditions like equals, giving a rain condition when the drizzle is the accurate one .

<details>

```javascript
let weather_enum = 0;

    // ref: https://openweathermap.org/weather-conditions
    // thunderstorm
    if (weather_id_x === 2) weather_enum = 3;
    // rain
@>  else if (weather_id_x === 3 || weather_id_x === 5) weather_enum = 2;
    // snow
    else if (weather_id_x === 6) weather_enum = 5;
    // clear
    else if (weather_id === 800) weather_enum = 0;
    // cloudy
    else if (weather_id_x === 8) weather_enum = 1;
    // windy
    else weather_enum = 4;

    return Functions.encodeUint256(weather_enum);
```
</details>

**Impact:**\
Give a inaccurate weather info.

**Recommended Mitigation:**\
Add enum member [6] as the new drizzle condition:

<details><summary>Fix</summary>

On `DeployWeatherNft.js`
```diff
const source = fs.readFileSync("./functionsSource/GetWeather.js").toString();
  let secretsEncrypted;
  let conf;
- const weathers = [0, 1, 2, 3, 4, 5];
+ const weathers = [0, 1, 2, 3, 4, 5, 6];
  const weatherURI = [
    "ipfs://bafkreif52aceqnvitpjb6twotibvtyi2mf4iey734lmmadbrxmykwfu3my",
    "ipfs://bafkreidt3ybfli2nthf6u2gtujmarvqi54hf2gk2l3wvq344sjvitbcklq",
    "ipfs://bafkreigcmkxjwtl3kixa32j36y7fq5zwfov4mv4sh2sjmejqpi253wq2i4",
    "ipfs://bafkreign7pr3rsevvftkqvjllf5sv4thfqbxzxd4wg22bkeqtqfynum774",
    "ipfs://bafkreih5go3rg2ulfjowrmum2fqbv6mwptlbhg47taml6zmln3h56vloe4",
    "ipfs://bafkreie3x4z3rplwofdljwhvxrfnvkxbkqwvbxn7wr6vfbtkz2tyofqq54"
+   "ipfs://[A drizzle related image]"
  ];
```

On `WeatherNftStore.sol`
```diff
    // enums
    enum Weather {
        SUNNY,
        CLOUDY,
        RAINY,
        THUNDERSTORM,
        WINDY,
        SNOW,
+       DRIZZLE
    }
```
</details>

### [L-#] Missing validation of a minimum Link amount for Chainling Keepers cause revert when `performUpkeep` 

**Description:**\
`WeatherNft::requestMintWeatherNFT` function allow `0` like `_initLinkDeposit` param causing a revert when chainlink keepers try to execute `performUpkeep`

<details>

```javascript
function requestMintWeatherNFT(
        string memory _pincode,
        string memory _isoCode,
        bool _registerKeeper,
        uint256 _heartbeat,
@>      uint256 _initLinkDeposit
    ) external payable returns (bytes32 _reqId) {
        require(msg.value == s_currentMintPrice, WeatherNft__InvalidAmountSent());
        s_currentMintPrice += s_stepIncreasePerMint;

        if (_registerKeeper) {
            IERC20(s_link).safeTransferFrom(msg.sender, address(this), _initLinkDeposit);
        }

        _reqId = _sendFunctionsWeatherFetchRequest(_pincode, _isoCode);

        emit WeatherNFTMintRequestSent(msg.sender, _pincode, _isoCode, _reqId);

        s_funcReqIdToUserMintReq[_reqId] = UserMintRequest({
            user: msg.sender,
            pincode: _pincode,
            isoCode: _isoCode,
            registerKeeper: _registerKeeper,
            heartbeat: _heartbeat,
            initLinkDeposit: _initLinkDeposit
        });
    }
```


**Impact:**\
Every keepers execution reverts without the gas consummed can't be 0.

**Proof of Concept:**\
Add the following to the test suite:



**Recommended Mitigation:**\