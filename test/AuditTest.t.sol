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

    function testAux() public {
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
}
