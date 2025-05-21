// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsResponse} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsResponse.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/FunctionsClient.sol";
import {WeatherNft, WeatherNftStore} from "src/WeatherNft.sol";
import {MockLinkToken} from "./MockLinkToken.sol";

import {console2} from "forge-std/Test.sol";

/// @title Chainlink Functions Router EX interface.
contract MockFunctionsRouter {
    address client;
    uint256 requestId;
    uint256 FUNCTIONS_FEE = 10000;
    address linkToken;

    constructor(address _linkToken) {
        linkToken = _linkToken;
    }

    function initializer(address _client) public {
        client = _client;
    }

    function sendRequest(
        uint64 subscriptionId,
        bytes calldata data,
        uint16 dataVersion,
        uint32 callbackGasLimit,
        bytes32 donId
    ) external returns (bytes32) {
        requestId++;
        MockLinkToken(linkToken).transfer(address(0x1), FUNCTIONS_FEE);
        return bytes32(requestId);
    }

    function onTokenTransfer(address sender, uint256 amount, bytes calldata data) external {}

    function fulfill() external {
        FunctionsClient(client).handleOracleFulfillment(bytes32(requestId), bytes("3"), bytes(""));
    }
}
