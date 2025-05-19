// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {WeatherNft, WeatherNftStore} from "src/WeatherNft.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {Vm} from "forge-std/Vm.sol";
// My imports
import {Deploy} from "src/Deploy.sol";

contract WeatherNftForkTest is Test {
    WeatherNft weatherNft;
    LinkTokenInterface linkToken;
    address functionsRouter;
    address user = makeAddr("user");
    // My states
    Deploy deploy;

    function setUp() external {
        // My own addresses
        deploy = new Deploy();
        address linkTokenAddr = deploy.linkTokenAddr();
        address upKeeperAddr = deploy.upKeeperAddr();
        address weatherNftAddr = deploy.weatherNftAddr();
        address routerAddr = deploy.routerAddr();
        // You can replace the weather nft contract with your own deployed contract
        weatherNft = WeatherNft(weatherNftAddr);
        linkToken = LinkTokenInterface(linkTokenAddr);
        functionsRouter = routerAddr;
        vm.deal(user, 1000e18);
        deal(address(linkToken), user, 1000e18);

        // fund weather nft sub
        vm.prank(user);
        linkToken.transferAndCall(functionsRouter, 100e18, abi.encode(15459));
    }

    function test_weatherNFT_Workflow() public {
        string memory pincode = "125001";
        string memory isoCode = "IN";
        bool registerKeeper = true;
        uint256 heartbeat = 12 hours;
        uint256 initLinkDeposit = 5e18;
        uint256 tokenId = weatherNft.s_tokenCounter();

        vm.startPrank(user);
        linkToken.approve(address(weatherNft), initLinkDeposit);
        vm.recordLogs();
        weatherNft.requestMintWeatherNFT{value: weatherNft.s_currentMintPrice()}(
            pincode, isoCode, registerKeeper, heartbeat, initLinkDeposit
        );
        vm.stopPrank();

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 reqId;
        for (uint256 i; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("WeatherNFTMintRequestSent(address,string,string,bytes32)")) {
                (,,, reqId) = abi.decode(logs[i].data, (address, string, string, bytes32));
                break;
            }
        }
        assert(reqId != bytes32(0));

        (
            uint256 reqHeartbeat,
            address reqUser,
            bool reqRegisterKeeper,
            uint256 reqInitLinkDeposit,
            string memory reqPincode,
            string memory reqIsoCode
        ) = weatherNft.s_funcReqIdToUserMintReq(reqId);
        assertEq(reqUser, user);
        assertEq(reqHeartbeat, heartbeat);
        assertEq(reqInitLinkDeposit, initLinkDeposit);
        assertEq(reqIsoCode, isoCode);
        assertEq(reqPincode, pincode);
        assertEq(reqRegisterKeeper, registerKeeper);

        vm.prank(functionsRouter);
        bytes memory weatherResponse = abi.encode(WeatherNftStore.Weather.RAINY);
        weatherNft.handleOracleFulfillment(reqId, weatherResponse, "");

        vm.prank(user);
        weatherNft.fulfillMintRequest(reqId);

        (
            uint256 infoHeartbeat,
            uint256 infoLastFulfilledAt,
            uint256 infoUpkeepId,
            string memory infoPincode,
            string memory infoIsoCode
        ) = weatherNft.s_weatherNftInfo(tokenId);
        assertEq(infoHeartbeat, heartbeat);
        assertEq(infoIsoCode, isoCode);
        assertEq(infoLastFulfilledAt, block.timestamp);
        assertEq(infoPincode, pincode);
        assert(infoUpkeepId > 0);
        assertEq(uint8(weatherNft.s_tokenIdToWeather(tokenId)), uint8(WeatherNftStore.Weather.RAINY));
        // ULTIMOOOOOO
        // getting token uri
        string memory tokenURI = weatherNft.tokenURI(tokenId);

        // automation check
        bytes memory encodedTokenId = abi.encode(tokenId);
        (bool weatherUpdateNeeded,) = weatherNft.checkUpkeep(encodedTokenId);
        assert(weatherUpdateNeeded == false);

        // time travelling to reach heartbeat for weather update
        vm.warp(block.timestamp + heartbeat);
        (bool weatherUpdateNeeded2, bytes memory performData) = weatherNft.checkUpkeep(encodedTokenId);
        assert(weatherUpdateNeeded2 == true);
        assertEq(performData, encodedTokenId);

        // chainlink keeper nodes call the performupkeep func with the encoded tokenid in order to request for current weather
        // the request is sent to chainlink functions with the user's pincode and isocode, to update the current weather for nft
        vm.recordLogs();
        weatherNft.performUpkeep(performData);

        // fetching request id
        Vm.Log[] memory entries = vm.getRecordedLogs();
        uint256 tokenIdToUpdate;
        bytes32 tokenIdUpdateReq;
        for (uint256 i; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("NftWeatherUpdateRequestSend(uint256,bytes32,uint256)")) {
                (tokenIdToUpdate, tokenIdUpdateReq) = abi.decode(entries[i].data, (uint256, bytes32));
                break;
            }
        }

        assert(tokenIdUpdateReq != bytes32(0));
        assertEq(tokenIdToUpdate, tokenId);
        assertEq(weatherNft.s_funcReqIdToTokenIdUpdate(tokenIdUpdateReq), tokenId);

        vm.prank(functionsRouter);
        bytes memory newWeatherResponse = abi.encode(WeatherNftStore.Weather.CLOUDY);
        weatherNft.handleOracleFulfillment(tokenIdUpdateReq, newWeatherResponse, "");
        assertEq(uint8(weatherNft.s_tokenIdToWeather(tokenId)), uint8(WeatherNftStore.Weather.CLOUDY));

        string memory newTokenURI = weatherNft.tokenURI(tokenId);
        assertNotEq(tokenURI, newTokenURI);
    }

    // function testAudit() public {
    //     string memory pincode = "125001";
    //     string memory isoCode = "IN";
    //     bool registerKeeper = true;
    //     uint256 heartbeat = 12 hours;
    //     uint256 initLinkDeposit = 5e18;
    //     uint256 tokenId = weatherNft.s_tokenCounter();

    //     vm.startPrank(user);
    //     linkToken.approve(address(weatherNft), initLinkDeposit);

    //     bytes32 requestId = weatherNft.requestMintWeatherNFT{value: weatherNft.s_currentMintPrice()}(
    //         pincode, isoCode, registerKeeper, heartbeat, initLinkDeposit
    //     );
    //     vm.stopPrank();

    //     weatherNft.fulfillMintRequest(requestId);
    // }
}
