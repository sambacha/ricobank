// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {AggregatorInterface} from "../lib/feedbase/src/adapters/ChainlinkAdapter.sol";
import "../src/mixin/math.sol";
import {Vat} from "../src/vat.sol";
import {UniSetUp} from "./UniHelper.sol";
import {BankDiamond} from "../src/diamond.sol";

interface WethLike {
    function deposit() external payable;
    function approve(address, uint256) external;
    function allowance(address, address) external returns (uint256);
    function balanceOf(address) external returns (uint256);
}

abstract contract BaseHelper is Math, Test, UniSetUp {
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant RAI = 0x03ab458634910AaD20eF5f1C8ee96F1D6ac54919;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant DAI_USD_AGG = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;
    address public constant XAU_USD_AGG = 0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6;
    address public constant WETH_USD_AGG = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address public constant RAI_ETH_AGG = 0x4ad7B025127e89263242aB68F0f9c4E5C033B489;
    address public constant NFPM = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address public constant VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    bytes32 public constant RICO_RISK_TAG = "rico:risk";
    bytes32 public constant RISK_RICO_TAG = "risk:rico";
    bytes32 public constant RICO_REF_TAG = "rico:ref";
    bytes32 public constant XAU_USD_TAG = "xau:usd";
    bytes32 public constant DAI_REF_TAG = "dai:ref";
    bytes32 public constant DAI_USD_TAG = "dai:usd";
    bytes32 public constant WETH_REF_TAG = "weth:ref";
    bytes32 public constant WETH_USD_TAG = "weth:usd";

    bytes32 public constant RAI_ILK = "rai";
    bytes32 public constant WETH_ILK = "weth";
    bytes32 public constant uilk = "uninft";

    uint24 public constant RICO_FEE = 500;
    uint24 public constant RISK_FEE = 3000;
    uint256 public constant HOOK_ROOM = 8;
    uint256 public constant CL_DEC = 8;
    uint256 public constant WETH_REF_VAL = 805830286360171930170219164;
    uint256 public constant GOLD_REF_VAL = 1000000000000000000000000000;
    address public immutable self = payable(address(this));

    bytes32[] public empty = new bytes32[](0);
    address payable public bank;

    receive() external payable {}

    function _ink(bytes32 ilk, address usr) internal view returns (uint256) {
        return abi.decode(Vat(bank).ink(ilk, usr), (uint256));
    }

    function get_rico_sqrtx96(uint256 par) internal view returns (uint160 sqrt_ratio_x96) {
        // get ricodai price given par, ref and 1 dai = 1 usd. ricodai should be par * ref/usd
        // ie xauusd = 1900, init par = 1.0, pool price should be 1 rico costs 1900 dai
        AggregatorInterface xauusd_agg = AggregatorInterface(XAU_USD_AGG);
        (, int256 res,,,) = xauusd_agg.latestRoundData();
        uint256 xauusd = uint256(res);
        uint256 ratio = par * xauusd / 10 ** CL_DEC;
        uint256 sqrt_ratio = sqrt(ratio * RAY);
        sqrt_ratio_x96 = uint160(sqrt_ratio * X96 / RAY);
    }

    function make_diamond() internal returns (address payable deployed) {
        return payable(address(new BankDiamond()));
    }

    // nfpm hook needs uniswap wrapper to interact with solc v7
    function make_uniwrapper() internal returns (address deployed) {
        bytes memory args = abi.encode("");
        bytes memory bytecode =
            abi.encodePacked(vm.getCode("../lib/feedbase/artifacts/src/adapters/UniWrapper.sol:UniWrapper"), args);
        assembly {
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
        }
    }

    function assertClose(uint256 v1, uint256 v2, uint256 rel) internal {
        uint256 abs = v1 / rel;
        assertGt(v1 + abs, v2);
        assertLt(v1 - abs, v2);
    }

    // Babylonian method for square root
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    // useful for clarity wrt which ilks keep drips
    function single(bytes32 x) internal pure returns (bytes32[] memory res) {
        res = new bytes32[](1);
        res[0] = x;
    }
}
