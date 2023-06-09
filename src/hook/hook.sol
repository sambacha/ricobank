// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.20;

interface Hook {
    function frobhook(
        address sender, bytes32 i, address u, bytes calldata dink, int dart
    ) external returns (bool safer);
    function grabhook(
        bytes32 i, address u, uint bill, address keeper, uint rush, uint cut
    ) external returns (bytes memory);
    function safehook(
        bytes32 i, address u
    ) view external returns (uint, uint);
    function ink(bytes32 i, address u) external returns (bytes memory);
}
