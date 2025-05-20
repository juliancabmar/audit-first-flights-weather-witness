### [S-#] TITLE (Root Cause + Impact)

**Description:**\

**Impact:**\

**Proof of Concept:**\

**Recommended Mitigation:**\


### [S-#] If an error in `WeatherNft::fulfillMintRequest` occurs the user can't withdraw the deposited Link.

**Description:**\
If an error occurs in WeatherNft::fulfillMintRequest (e.g., due to invalid response data or other issues), the LINK tokens deposited by the user for Chainlink Keepers remain locked in the contract, with no way for the user to withdraw them.

**Impact:**\
Users may lose their deposited LINK if the minting process fails, leading to financial loss and reduced trust in the platform.

**Proof of Concept:**\
Add the following to the test suite:

<details><summary>PoC</summary>

```javascript
function testOnfulfillMintRequestFailDepositedLinkStucks() public {
    string memory pincode = "0000";
    string memory isoCode = "XX";
    bool registerKeeper = true;
    uint256 heartbeat = 12 hours;
    uint256 initLinkDeposit = 5e18;
    uint256 tokenId = weatherNft.s_tokenCounter();

    vm.startPrank(user);

    linkToken.approve(address(weatherNft), initLinkDeposit);

    bytes32 reqId = weatherNft.requestMintWeatherNFT{value: weatherNft.s_currentMintPrice()}(
        pincode, isoCode, registerKeeper, heartbeat, initLinkDeposit
    );
    vm.stopPrank();

    vm.prank(functionsRouter);
    bytes memory weatherResponse = abi.encode(WeatherNftStore.Weather.RAINY);
    weatherNft.handleOracleFulfillment(reqId, weatherResponse, "");

    vm.prank(user);
    vm.expectRevert(WeatherNftStore.WeatherNft__Unauthorized.selector);
    // forcing a revert
    weatherNft.fulfillMintRequest(bytes32("6666"));

    assertEq(linkToken.balanceOf(address(weatherNft)), 5e18);
}
```
</details>

**Recommended Mitigation:**\
Add a withdraw functionality to `WeatherNft` that check the owner of the requestId.

<details><summary>Example</summary>

On `WeathersNftStore` add:

```diff
    // variables
    uint256 public s_tokenCounter;
    mapping(Weather => string) public s_weatherToTokenURI;
    FunctionsConfig public s_functionsConfig;
    mapping(bytes32 => UserMintRequest) public s_funcReqIdToUserMintReq;
    mapping(bytes32 => MintFunctionReqResponse) public s_funcReqIdToMintFunctionReqResponse;
    mapping(bytes32 => uint256) public s_funcReqIdToTokenIdUpdate;
+   mapping(address => uint256) addressToLinkDeposit;
```

On `WeatherNft` add:

```diff
    // functions
+   fucntion withdrawLinks(_tokenId) external {
+       address owner = _ownerOf(_tokenId);
+       if (owner != msg.sender) {
+           revert WeatherNft__Unauthorized()
+       } else {
+           LinkTokenInterface(s_link).approve(owner, addressToLinkDeposit[owner]);
+           IERC20(s_link).safeTransferFrom(address(this), address(this), addressToLinkDeposit[owner]);
+       }
+   }
 
    function updateFunctionsGasLimit(uint32 newGaslimit) external onlyOwner {
        s_functionsConfig.gasLimit = newGaslimit;
    }

    function updateSubId(uint64 newSubId) external onlyOwner {
        s_functionsConfig.subId = newSubId;
    }

    function updateSource(string memory newSource) external onlyOwner {
        s_functionsConfig.source = newSource;
    }
```

```diff
    function requestMintWeatherNFT( // check
    string memory _pincode, string memory _isoCode, bool _registerKeeper, uint256 _heartbeat, uint256 _initLinkDeposit)
        external
        payable
        returns (bytes32 _reqId)
    {
        // @? - multicall exploit
        require(msg.value == s_currentMintPrice, WeatherNft__InvalidAmountSent());
        s_currentMintPrice += s_stepIncreasePerMint;

        if (_registerKeeper) {
+           addressToLinkDeposit[msg.sender] = _initLinkDeposit;
            IERC20(s_link).safeTransferFrom(msg.sender, address(this), _initLinkDeposit);
        }
        
        _reqId = _sendFunctionsWeatherFetchRequest(_pincode, _isoCode);

        emit WeatherNFTMintRequestSent(msg.sender, _pincode, _isoCode, _reqId);

        s_funcReqIdToUserMintReq[_reqId] = UserMintRequest({
            user: msg.sender,
            pincode: _pincode,
            isoCode: _isoCode,
            // e - using a keeper or not
            registerKeeper: _registerKeeper,
            heartbeat: _heartbeat,
            initLinkDeposit: _initLinkDeposit
        });
    }

```

</details>

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
`WeatherNft::requestMintWeatherNFT` function allow `0` like `_initLinkDeposit` param causing a fail when chainlink keepers try to execute `performUpkeep`

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
</details>


**Impact:**\
Every keeper's execution fails bacause the gas consummed for it can't be 0.

**Recommended Mitigation:**\
Check and revert if `_initLinkDeposit` param is `0`

```diff
function requestMintWeatherNFT(
        string memory _pincode,
        string memory _isoCode,
        bool _registerKeeper,
        uint256 _heartbeat,
        uint256 _initLinkDeposit
    ) external payable returns (bytes32 _reqId) {
        require(msg.value == s_currentMintPrice, WeatherNft__InvalidAmountSent());
+       require(_initLinkDeposit > 0, "Init Link deposit can't be 0");
        s_currentMintPrice += s_stepIncreasePerMint;

        if (_registerKeeper) {
            IERC20(s_link).safeTransferFrom(msg.sender, address(this), _initLinkDeposit);
        }
.
.
.
```
 