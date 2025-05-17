// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console2} from "forge-std/Test.sol";

/// @title Chainlink Functions Router EX interface.
contract MockUpKeeper {
    address client;

    function setClient(address _client) public {
        client = _client;
    }
}
