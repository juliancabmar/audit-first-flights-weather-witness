// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console2} from "forge-std/Test.sol";
import {IAutomationRegistrarInterface} from "../interfaces/IAutomationRegistrarInterface.sol";

/// @title Chainlink Functions Router EX interface.
contract MockUpKeeper {
    address client;
    uint256 counter;

    function setClient(address _client) public {
        client = _client;
    }

    function registerUpkeep(IAutomationRegistrarInterface.RegistrationParams calldata requestParams)
        external
        returns (uint256)
    {
        counter++;
        return counter;
    }
}
