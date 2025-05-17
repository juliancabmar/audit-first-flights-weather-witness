// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsResponse} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsResponse.sol";
import {console2} from "forge-std/Test.sol";

/// @title Chainlink Functions Router EX interface.
contract MockFunctionsRouter {
    address client;

    function setClient(address _client) public {
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
    ) external pure returns (bytes32) {
        console2.log("MY SubscriptionID: ", subscriptionId);
        return 0;
    }

    function onTokenTransfer(address sender, uint256 amount, bytes calldata data) external {}

    function fulfill(address _client) external returns (FunctionsResponse.FulfillResult, uint96) {}
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
