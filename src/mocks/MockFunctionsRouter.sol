// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsResponse} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsResponse.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_X/FunctionsClient.sol";
import {WeatherNft, WeatherNftStore} from "src/WeatherNft.sol";

import {console2} from "forge-std/Test.sol";

/// @title Chainlink Functions Router EX interface.
contract MockFunctionsRouter {
    address client;
    uint256 requestId;

    function initializer(address _client) public {
        client = _client;
    }
    /// @notice Sends a request using the provided subscriptionId
    /// @param subscriptionId - A unique subscription ID allocated by billing system,
    /// a client can make requests from different contracts referencing the same subscription
    /// @param data - CBOR encoded Chainlink Functions request data, use FunctionsClient API to encode a request
    /// @param dataVersion - Gas limit for the fulfillment callback
    /// @param callbackGasLimit - Gas limit for the fulfillment callback
    /// @param donId - An identifier used to determine which route to send the request along
    /// @return requestId - A unique request identifier

    function sendRequest(
        uint64 subscriptionId,
        bytes calldata data,
        uint16 dataVersion,
        uint32 callbackGasLimit,
        bytes32 donId
    ) external returns (bytes32) {
        requestId++;
        return bytes32(requestId);
    }

    function onTokenTransfer(address sender, uint256 amount, bytes calldata data) external {}

    function fulfill() external {
        // fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err)
        FunctionsClient(client).handleOracleFulfillment(bytes32(requestId), bytes("3"), bytes(""));
        // WeatherNft(client).fulfillRequest(bytes32(requestId), bytes("3"), bytes(""));
    }
}

// function _sendRequest(
//     bytes memory data,
//     uint64 subscriptionId,
//     uint32 callbackGasLimit,
//     bytes32 donId
//   ) internal returns (bytes32) {
//     bytes32 requestId = i_router.sendRequest(
//       subscriptionId,
//       data,
//       FunctionsRequest.REQUEST_DATA_VERSION,
//       callbackGasLimit,
//       donId
//     );
//     emit RequestSent(requestId);
//     return requestId;
//   }
