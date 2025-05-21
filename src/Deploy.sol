// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {console} from "forge-std/Test.sol";
import {WeatherNft, WeatherNftStore} from "src/WeatherNft.sol";
import {MockLinkToken} from "./mocks/MockLinkToken.sol";
import {LinkToken} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol";
import {MockUpKeeper} from "./mocks/MockUpKeeper.sol";
import {MockFunctionsRouter} from "./mocks/MockFunctionsRouter.sol";

contract Deploy {
    address public linkTokenAddr;
    address public upKeeperAddr;
    address public weatherNftAddr;
    address public routerAddr;

    WeatherNft weatherNft;
    MockUpKeeper mockUpKeeper;

    LinkToken linkToken;
    // MockLinkToken mockLinkToken;
    MockFunctionsRouter mockRouter;

    constructor() {
        linkToken = new LinkToken();
        // mockLinkToken = new MockLinkToken();
        mockRouter = new MockFunctionsRouter(address(linkToken));
        mockUpKeeper = new MockUpKeeper();

        linkTokenAddr = address(linkToken);
        // linkTokenAddr = address(mockLinkToken);
        upKeeperAddr = address(mockUpKeeper);
        routerAddr = address(mockRouter);

        (
            WeatherNftStore.Weather[] memory weathers,
            string[] memory weatherURIs,
            address _functionsRouter,
            WeatherNftStore.FunctionsConfig memory config,
            uint256 currentMintPrice,
            uint256 stepIncreasePerMint,
            address link,
            address keeperRegistry,
            address keeperRegistrar,
            uint32 upkeepGaslimit
        ) = getWeatherTokenParams();

        weatherNft = new WeatherNft(
            weathers,
            weatherURIs,
            _functionsRouter,
            config,
            currentMintPrice,
            stepIncreasePerMint,
            link,
            keeperRegistry,
            keeperRegistrar,
            upkeepGaslimit
        );
        weatherNftAddr = address(weatherNft);
    }

    function getWeatherTokenParams()
        public
        returns (
            WeatherNftStore.Weather[] memory,
            string[] memory,
            address,
            WeatherNftStore.FunctionsConfig memory,
            uint256,
            uint256,
            address,
            address,
            address,
            uint32
        )
    {
        WeatherNftStore.Weather[] memory weathers = new WeatherNftStore.Weather[](6);
        weathers[0] = WeatherNftStore.Weather.SUNNY;
        weathers[1] = WeatherNftStore.Weather.CLOUDY;
        weathers[2] = WeatherNftStore.Weather.RAINY;
        weathers[3] = WeatherNftStore.Weather.THUNDERSTORM;
        weathers[4] = WeatherNftStore.Weather.WINDY;
        weathers[5] = WeatherNftStore.Weather.SNOW;
        string[] memory weatherURIs = new string[](6);
        weatherURIs[0] = "ipfs://bafkreif52aceqnvitpjb6twotibvtyi2mf4iey734lmmadbrxmykwfu3my";
        weatherURIs[1] = "ipfs://bafkreidt3ybfli2nthf6u2gtujmarvqi54hf2gk2l3wvq344sjvitbcklq";
        weatherURIs[2] = "ipfs://bafkreigcmkxjwtl3kixa32j36y7fq5zwfov4mv4sh2sjmejqpi253wq2i4";
        weatherURIs[3] = "ipfs://bafkreign7pr3rsevvftkqvjllf5sv4thfqbxzxd4wg22bkeqtqfynum774";
        weatherURIs[4] = "ipfs://bafkreih5go3rg2ulfjowrmum2fqbv6mwptlbhg47taml6zmln3h56vloe4";
        weatherURIs[5] = "ipfs://bafkreie3x4z3rplwofdljwhvxrfnvkxbkqwvbxn7wr6vfbtkz2tyofqq54";

        // address functionsRouter,
        WeatherNftStore.FunctionsConfig memory _config = WeatherNftStore.FunctionsConfig({
            source: "console.log('HELLO')",
            encryptedSecretsURL: "",
            subId: type(uint64).max,
            gasLimit: 2100000000,
            donId: 0
        });
        uint256 _currentMintPrice = 1 ether;
        uint256 _stepIncreasePerMint = 1000;
        address _link = linkTokenAddr;
        // address _link = address(mockLinkToken);
        address _keeperRegistry = address(0x0);
        address _keeperRegistrar = upKeeperAddr;
        uint32 _upkeepGaslimit = 210000000;

        return (
            weathers,
            weatherURIs,
            routerAddr,
            _config,
            _currentMintPrice,
            _stepIncreasePerMint,
            _link,
            _keeperRegistry,
            _keeperRegistrar,
            _upkeepGaslimit
        );
    }
}
