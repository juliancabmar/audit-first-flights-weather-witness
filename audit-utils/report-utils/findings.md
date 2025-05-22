### [S-#] Contract `WeatherNft` has payable functions, but not have a withdraw mechanism

**Description:**\
The `WeatherNft` contract include the `requestMintWeatherNFT()` payable function but lacks a mechanism for withdrawing collected funds, leaving them locked in the contract.

**Impact:**\
Funds collected through payable functions cannot be accessed, leading a financial to the contract owner.

```solidity
    function requestMintWeatherNFT(string memory _pincode, string memory _isoCode, bool _registerKeeper, uint256 _heartbeat, uint256 _initLinkDeposit)
        external
@>      payable
        returns (bytes32 _reqId)
    {
        require(msg.value == s_currentMintPrice, WeatherNft__InvalidAmountSent());
        s_currentMintPrice += s_stepIncreasePerMint;

        if (_registerKeeper) {
            addressToLinkDeposit[msg.sender] = _initLinkDeposit;
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

**Recommended Mitigation:**\
Add a `onlyOwner` withdraw function:

```diff
    .
    .
    // functions
+   function withdraw() external onlyOwner {
+       uint256 balance = address(this).balance;
+       require(balance > 0, "No ETH to withdraw");
+       (bool success, ) = msg.sender.call{value: balance}("");
+       require(success, "Withdraw failed");
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

    function updateEncryptedSecretsURL(bytes memory newEncryptedSecretsURL) external onlyOwner {
        s_functionsConfig.encryptedSecretsURL = newEncryptedSecretsURL;
    }
    .
    .
```



### [S-#] `WeatherNft::performUpkeep` can be called by anyone with any parameter
**Description:**\
The `performUpkeep` function haven't any address or input data validation in his `performData` parameter, making it can be called from any address and with any parameter 

**Impact:**
- If the decoded `performData` is a valid TokenId: the related token update his wheather data.
- If the decoded `performData` is not a valid TokenId: the WeatherNft contract will send a request to chainlink functions a invalid request.
- In all scenarios, unauthorized calls to performUpkeep can waste gas and deplete the contract's LINK balance.


**Proof of Concept:**\
Add the following to the test suite:

<details><summary>PoC</summary>

```javascript
function testCanBeCalledByAnyoneWithAnithing() public {
    string memory pincode = "125001";
    string memory isoCode = "IN";
    bool registerKeeper = true;
    uint256 heartbeat = 12 hours;
    uint256 initLinkDeposit = 5e18;
    address attacker = makeAddr("attacker");
    uint256 functionRouterBalance;

    vm.startPrank(user);

    linkToken.approve(address(weatherNft), initLinkDeposit);

    bytes32 reqId = weatherNft.requestMintWeatherNFT{value: weatherNft.s_currentMintPrice()}(
        pincode, isoCode, registerKeeper, heartbeat, initLinkDeposit
    );
    vm.stopPrank();

    vm.prank(functionsRouter);
    bytes memory weatherResponse = abi.encode(WeatherNftStore.Weather.RAINY);
    weatherNft.handleOracleFulfillment(reqId, weatherResponse, "");

    uint256 userTokenId = weatherNft.s_tokenCounter();
    vm.prank(user);
    weatherNft.fulfillMintRequest(reqId);

    //// If the decoded `performData` is a valid TokenId: the related token update his wheather data.

    // Retrieve the lastFulfilledAt value
    (, uint256 prevLastFulfilled,,,) = weatherNft.s_weatherNftInfo(userTokenId);
    // advance some in time
    vm.warp(1 hours);

    // get the functionsRouter balance
    functionRouterBalance = linkToken.balanceOf(functionsRouter);
    vm.prank(attacker);
    weatherNft.performUpkeep(abi.encode(userTokenId));

    vm.prank(functionsRouter);
    weatherResponse = abi.encode(WeatherNftStore.Weather.RAINY);
    weatherNft.handleOracleFulfillment(reqId, weatherResponse, "");

    (, uint256 lastFulfilled,,,) = weatherNft.s_weatherNftInfo(userTokenId);
    // Check for update
    assert(prevLastFulfilled < lastFulfilled);
    // Check if router balance decreased
    assert(functionRouterBalance > linkToken.balanceOf(functionsRouter));

    //// If the decoded `performData` is not a valid TokenId: the WeatherNft contract will send a request to chainlink functions a invalid request.

    // get the functionsRouter balance
    functionRouterBalance = linkToken.balanceOf(functionsRouter);
    vm.prank(attacker);
    weatherNft.performUpkeep(abi.encode("HELLO FRIENDS"));

    // Check if router balance decreased
    assert(functionRouterBalance > linkToken.balanceOf(functionsRouter));
}
```
</details>

**Recommended Mitigation:**\
Allow only the Weather Nft Owner and the related Keeper to call `performUpkeep`

Example:

```solidity
function performUpkeep(bytes calldata performData) external override {
+   require(msg.sender == s_keeperRegistry, "Unauthorized caller");
    uint256 _tokenId = abi.decode(performData, (uint256));
+   if (_ownerOf(_tokenId) != msg.sender) {
+       revert WeatherNft__Unauthorized();
+   }
    uint256 upkeepId = s_weatherNftInfo[_tokenId].upkeepId;

    s_weatherNftInfo[_tokenId].lastFulfilledAt = block.timestamp;

    // make functions request
    string memory pincode = s_weatherNftInfo[_tokenId].pincode;
    string memory isoCode = s_weatherNftInfo[_tokenId].isoCode;

    bytes32 _reqId = _sendFunctionsWeatherFetchRequest(pincode, isoCode);
    s_funcReqIdToTokenIdUpdate[_reqId] = _tokenId;

    emit NftWeatherUpdateRequestSend(_tokenId, _reqId, upkeepId);
}
```

### [S-#] Functions `WeatherNft::fulfillMintRequest` and `WeatherNft::_fulfillWeatherUpdate` empty return after Chainlink Function response check.

**Description:**\
`WeatherNft::fulfillMintRequest` and `WeatherNft::_fulfillWeatherUpdate` make checks on the response length and the error message length and if a issue is find, return the function without give any reason.

<details>

On `WeatherNft::fulfillMintRequest`:

```javascript
function fulfillMintRequest(bytes32 requestId) external {
    require(msg.sender == s_reqIdToUser[requestId], "Invalid user");

    bytes memory response = s_funcReqIdToMintFunctionReqResponse[requestId].response;
    bytes memory err = s_funcReqIdToMintFunctionReqResponse[requestId].err;

    require(response.length > 0 || err.length > 0, WeatherNft__Unauthorized());
@>  if (response.length == 0 || err.length > 0) {
@>      return;
@>  }

    UserMintRequest memory _userMintRequest = s_funcReqIdToUserMintReq[requestId];
    .
    .
```
On `WeatherNft::_fulfillWeatherUpdate`:

```javascript
function _fulfillWeatherUpdate(bytes32 requestId, bytes memory response, bytes memory err) internal {
@>  if (response.length == 0 || err.length > 0) {
@>      return;
@>  }

    uint256 tokenId = s_funcReqIdToTokenIdUpdate[requestId];
    .
    .
```
</details>

**Impact:**\
The user never knows what issue in the Chainlin Function response cause the return

**Recommended Mitigation:**\
Return the consice issue.

<details><summary>Example</summary>

On `WeatherNft::fulfillMintRequest`:

```diff
function fulfillMintRequest(bytes32 requestId) external {
    require(msg.sender == s_reqIdToUser[requestId], "Invalid user");

    bytes memory response = s_funcReqIdToMintFunctionReqResponse[requestId].response;
    bytes memory err = s_funcReqIdToMintFunctionReqResponse[requestId].err;

    require(response.length > 0 || err.length > 0, WeatherNft__Unauthorized());
-   if (response.length == 0 || err.length > 0) {
-       return;
-   }
+   if (response.length == 0) {
+       require(false, "Response Empty");
+   } else if (err.length > 0) {
+       require(false, string(err));
+   }

    UserMintRequest memory _userMintRequest = s_funcReqIdToUserMintReq[requestId];
    .
    .
```
On `WeatherNft::_fulfillWeatherUpdate`:
```diff
function _fulfillWeatherUpdate(bytes32 requestId, bytes memory response, bytes memory err) internal {
-   if (response.length == 0 || err.length > 0) {
-       return;
-   }
+   if (response.length == 0) {
+       require(false, "Response Empty");
+   } else if (err.length > 0) {
+       require(false, string(err));
+   }

    uint256 tokenId = s_funcReqIdToTokenIdUpdate[requestId];
    .
    .
```
</details>

### [S-#] Event on `WeatherNft::requestMintWeatherNFT` makes `WeatherNft::fulfillMintRequest` front-runnable

**Description:**\
When the event `WeatherNftStore::WeatherNFTMintRequestSent` is emited on `WeatherNft::requestMintWeatherNFT` execution, his `reqId` parameter can be catched and used for front-run the minting of Weather Nft calling `WeatherNft::fulfillMintRequest` before the legit user.

<details>

```javascript
function requestMintWeatherNFT(
    string memory _pincode, string memory _isoCode, bool _registerKeeper, uint256 _heartbeat, uint256 _initLinkDeposit)
        external
        payable
        returns (bytes32 _reqId)
    {
        require(msg.value == s_currentMintPrice, WeatherNft__InvalidAmountSent());
        s_currentMintPrice += s_stepIncreasePerMint;

        if (_registerKeeper) {
            addressToLinkDeposit[msg.sender] = _initLinkDeposit;
            IERC20(s_link).safeTransferFrom(msg.sender, address(this), _initLinkDeposit);
        }

        _reqId = _sendFunctionsWeatherFetchRequest(_pincode, _isoCode);

@>      emit WeatherNFTMintRequestSent(msg.sender, _pincode, _isoCode, _reqId);

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

**Impact:**\
Steal the Weather Nft from the user

**Proof of Concept:**\
Add the following to the test suite:

<details><summary>PoC</summary>

```javascript
function testfulfillMintRequestCanBeFrontRun() public {
    string memory pincode = "125001";
    string memory isoCode = "IN";
    bool registerKeeper = true;
    uint256 heartbeat = 12 hours;
    uint256 initLinkDeposit = 5e18;

    address attacker = makeAddr("attacker");

    vm.startPrank(user);
    linkToken.approve(address(weatherNft), initLinkDeposit);

    // The attacker is waiting for the right event log
    vm.recordLogs();
    weatherNft.requestMintWeatherNFT{value: weatherNft.s_currentMintPrice()}(
        pincode, isoCode, registerKeeper, heartbeat, initLinkDeposit
    );
    vm.stopPrank();

    Vm.Log[] memory logs = vm.getRecordedLogs();
    bytes32 reqId;
    for (uint256 i; i < logs.length; i++) {
        if (logs[i].topics[0] == keccak256("WeatherNFTMintRequestSent(address,string,string,bytes32)")) {
            // Get the reqId
            (,,, reqId) = abi.decode(logs[i].data, (address, string, string, bytes32));
            break;
        }
    }

    vm.prank(functionsRouter);
    bytes memory weatherResponse = abi.encode(WeatherNftStore.Weather.RAINY);
    weatherNft.handleOracleFulfillment(reqId, weatherResponse, "");

    // calculates the new tokenId
    uint256 tokenIdAttacker = weatherNft.s_tokenCounter();
    // Minting with the user reqId before he
    vm.prank(attacker);
    weatherNft.fulfillMintRequest(reqId);
    assertEq(attacker, weatherNft.ownerOf(tokenIdAttacker));
}
```
</details>

**Recommended Mitigation:**\
Associate the requestId with the user and check this on `WeatherNft::fulfillMintRequest`

<details><summary>Example</summary>

On `WheatherNftStore` add:
```diff
    .
    .
    // variables
    uint256 public s_tokenCounter;
+   mapping(bytes32 => address) public s_reqIdToUser;
    mapping(Weather => string) public s_weatherToTokenURI;
    FunctionsConfig public s_functionsConfig;
    mapping(bytes32 => UserMintRequest) public s_funcReqIdToUserMintReq;
    mapping(bytes32 => MintFunctionReqResponse) public s_funcReqIdToMintFunctionReqResponse;
    mapping(bytes32 => uint256) public s_funcReqIdToTokenIdUpdate;
    .
    .
```
On `WeatherNft::requestMintWeatherNFT` add:
```diff
    function requestMintWeatherNFT(string memory _pincode, string memory _isoCode, bool _registerKeeper, uint256 _heartbeat, uint256 _initLinkDeposit)
        external
        payable
        returns (bytes32 _reqId)
    {
        require(msg.value == s_currentMintPrice, WeatherNft__InvalidAmountSent());
        s_currentMintPrice += s_stepIncreasePerMint;

        if (_registerKeeper) {
            addressToLinkDeposit[msg.sender] = _initLinkDeposit;
            IERC20(s_link).safeTransferFrom(msg.sender, address(this), _initLinkDeposit);
        }

        _reqId = _sendFunctionsWeatherFetchRequest(_pincode, _isoCode);

+       s_reqIdToUser[_reqId] = msg.sender;

        emit WeatherNFTMintRequestSent(msg.sender, _pincode, _isoCode, _reqId);
    .
    .
```
On `WeatherNft::fulfillMintRequest` add:
```diff
    function fulfillMintRequest(bytes32 requestId) external {
+       require(msg.sender == s_reqIdToUser[requestId], "Invalid user");
        bytes memory response = s_funcReqIdToMintFunctionReqResponse[requestId].response;
        bytes memory err = s_funcReqIdToMintFunctionReqResponse[requestId].err;

        require(response.length > 0 || err.length > 0, WeatherNft__Unauthorized());
        // @? - returns without a error reason
        if (response.length == 0 || err.length > 0) {
            return;
        }

        UserMintRequest memory _userMintRequest = s_funcReqIdToUserMintReq[requestId];
        uint8 weather = abi.decode(response, (uint8));
        uint256 tokenId = s_tokenCounter;
        s_tokenCounter++;
    .
    .
```
</details>


### [S-#] Request Id parameter can be used multiple times for WeatherNft minting

**Description:**\
The requestId parameter on `WeatherNft::fulfillMintRequest` function can be reused multiple times for minting Weather NFTs and this allows malicious users to replay the same requestId and mint multiple NFTs without paying additional fees.

**Impact:**
- Financial loss for the platform
- Inflation of the NFT supply
- Reduced trust in the system

**Proof of Concept:**\
Add the following to the test suite:

<details><summary>PoC</summary>

```javascript
function testRequestIdCanBeReusedForNewNftMints() public {
        string memory pincode = "125001";
        string memory isoCode = "IN";
        bool registerKeeper = true;
        uint256 heartbeat = 12 hours;
        uint256 initLinkDeposit = 5e18;
        // create attakers accounts
        address attackerA = makeAddr("attackerA");
        address attackerB = makeAddr("attackerB");
        address attackerC = makeAddr("attackerC");

        vm.startPrank(user);

        linkToken.approve(address(weatherNft), initLinkDeposit);

        bytes32 reqId = weatherNft.requestMintWeatherNFT{value: weatherNft.s_currentMintPrice()}(
            pincode, isoCode, registerKeeper, heartbeat, initLinkDeposit
        );
        vm.stopPrank();

        vm.prank(functionsRouter);
        bytes memory weatherResponse = abi.encode(WeatherNftStore.Weather.RAINY);
        weatherNft.handleOracleFulfillment(reqId, weatherResponse, "");

        // The valid WeatherNft minitng
        uint256 tokenIdUser = weatherNft.s_tokenCounter();
        vm.prank(user);
        weatherNft.fulfillMintRequest(reqId);

        // The invalid ones using the same requestId
        uint256 tokenIdAttackerA = weatherNft.s_tokenCounter();
        vm.prank(attackerA);
        weatherNft.fulfillMintRequest(reqId);

        uint256 tokenIdAttackerB = weatherNft.s_tokenCounter();
        vm.prank(attackerB);
        weatherNft.fulfillMintRequest(reqId);

        uint256 tokenIdAttackerC = weatherNft.s_tokenCounter();
        vm.prank(attackerC);
        weatherNft.fulfillMintRequest(reqId);

        assertEq(user, weatherNft.ownerOf(tokenIdUser));
        assertEq(attackerA, weatherNft.ownerOf(tokenIdAttackerA));
        assertEq(attackerB, weatherNft.ownerOf(tokenIdAttackerB));
        assertEq(attackerC, weatherNft.ownerOf(tokenIdAttackerC));
    }
```
</details>

**Recommended Mitigation:**\
Add a mechanism to mark the requestId as "used" after processing.

<details><summary>Example</summary>

On `WheatherNftStore` add:
```diff
    .
    .
    // variables
    uint256 public s_tokenCounter;
+   mapping(bytes32 => bool) public s_reqIdToAlreadyUsed;
    mapping(Weather => string) public s_weatherToTokenURI;
    FunctionsConfig public s_functionsConfig;
    mapping(bytes32 => UserMintRequest) public s_funcReqIdToUserMintReq;
    mapping(bytes32 => MintFunctionReqResponse) public s_funcReqIdToMintFunctionReqResponse;
    mapping(bytes32 => uint256) public s_funcReqIdToTokenIdUpdate;
    .
    .
```
On `WeatherNft::fulfillMintRequest` add:
```diff
    .
    .
    function fulfillMintRequest(bytes32 requestId) external {
+       require(!s_reqIdToAlreadyUsed[requestId], "Request Id already used");
+       s_reqIdToAlreadyUsed[requestId] = true;
        bytes memory response = s_funcReqIdToMintFunctionReqResponse[requestId].response;
        bytes memory err = s_funcReqIdToMintFunctionReqResponse[requestId].err;

        require(response.length > 0 || err.length > 0, WeatherNft__Unauthorized());
        // @? - returns without a error reason
        if (response.length == 0 || err.length > 0) {
            return;
        }

        UserMintRequest memory _userMintRequest = s_funcReqIdToUserMintReq[requestId];
        uint8 weather = abi.decode(response, (uint8));
        uint256 tokenId = s_tokenCounter;
        s_tokenCounter++;
    .
    .
```
</details>

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
+   function withdrawLinks(uint256 _tokenId) external {
+       address owner = _ownerOf(_tokenId);
+       if (owner != msg.sender) {
+           revert WeatherNft__Unauthorized();
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

<details><summary>Example</summary>

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
On `GetWeather.js`
```diff
    .
    .
    let weather_enum = 0;

    // ref: https://openweathermap.org/weather-conditions
    // thunderstorm
    if (weather_id_x === 2) weather_enum = 3;
    // rain
-   else if (weather_id_x === 3 || weather_id_x === 5) weather_enum = 2;
+   else if (weather_id_x === 3) weather_enum = 2;
+   // drizzle
+   else if (weather_id_x === 5) weather_enum = 6;
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
 