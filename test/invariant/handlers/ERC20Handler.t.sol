// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {Feedbase} from "../../../lib/feedbase/src/Feedbase.sol";
import {Gem} from "../../../lib/gemfab/src/gem.sol";
import {Vat} from "../../../src/vat.sol";
import {ERC20Handler} from "./ERC20Handler.sol";
import {BaseHelper} from "../../BaseHelper.sol";

contract ERC20HandlerTest is Test, BaseHelper {
    ERC20Handler handler;
    Feedbase feed;
    Vat vat;
    Gem rico;
    Gem risk;

    function setUp() external {
        handler = new ERC20Handler();
        bank = handler.bank();
        rico = handler.rico();
        risk = handler.risk();
        vat = Vat(bank);
        feed = handler.feed();
    }

    function test_handler_frob() public {
        uint256 ts1 = rico.totalSupply();
        handler.frob(0, 0, int256(10 * WAD), int256(1 * WAD));
        uint256 ts2 = rico.totalSupply();

        assertGt(ts2, ts1);
    }

    function test_handler_move() public {
        (bytes32 val1,) = feed.pull(handler.fsrc(), WETH_REF_TAG);
        handler.move(true);
        (bytes32 val2,) = feed.pull(handler.fsrc(), WETH_REF_TAG);

        assertGt(uint256(val2), uint256(val1));

        handler.move(false);
        (bytes32 val3,) = feed.pull(handler.fsrc(), WETH_REF_TAG);

        assertLt(uint256(val3), uint256(val2));
        assertClose(uint256(val3), uint256(val1), 1_000_000);
    }

    function test_handler_date() public {
        (, uint256 ttl1) = feed.pull(handler.fsrc(), WETH_REF_TAG);
        skip(10);
        handler.date(10);
        (, uint256 ttl2) = feed.pull(handler.fsrc(), WETH_REF_TAG);

        assertNotEq(ttl1, ttl2);
    }

    function test_handler_bail() public {
        // weth/ref is about 0.8. let actor 0 get unsafe and bail with actor 1.
        // bound() will not change inputs if they're within the range
        handler.frob(0, 0, int256(100 * WAD), int256(80 * WAD));
        handler.frob(1, 1, int256(200 * WAD), int256(150 * WAD));

        handler.move(false);

        uint256 ts1 = rico.totalSupply();
        handler.bail(1, 0);
        uint256 ts2 = rico.totalSupply();

        assertLt(ts2, ts1);

        for (uint256 i = 0; i < handler.NUM_ACTORS(); ++i) {
            address actor = handler.actors(i);
            int256 ink = int256(_ink(WETH_ILK, actor));
            int256 weth = int256(Gem(WETH).balanceOf(actor));
            int256 off = handler.ink_offset(actor);
            int256 init = int256(handler.ACTOR_WETH());
            assertEq(ink + weth, init + off);
        }
        assertGt(handler.ink_offset(handler.actors(1)), 0);
    }

    function test_handler_keep() public {
        handler.frob(0, 0, int256(100 * WAD), int256(50 * WAD));
        handler.wait(200);

        uint256 r1 = risk.totalSupply();
        handler.keep(0);
        uint256 r2 = risk.totalSupply();

        assertLt(r2, r1);
    }

    function test_handler_wait() public {
        uint256 ts1 = block.timestamp;
        handler.wait(5);
        uint256 ts2 = block.timestamp;

        assertEq(ts1 + 5, ts2);
    }

    function test_handler_drip() public {
        handler.frob(0, 0, int256(100 * WAD), int256(50 * WAD));
        handler.wait(200);

        uint256 j1 = Vat(bank).joy();
        handler.drip();
        uint256 j2 = Vat(bank).joy();

        assertGt(j2, j1);
    }

    function test_handler_mark_poke() public {
        uint256 p1 = Vat(bank).par();

        handler.mark(true);
        handler.mark(false);
        handler.wait(10);
        handler.poke();
        handler.wait(10);
        handler.poke();

        uint256 p2 = Vat(bank).par();
        assertEq(p2, p1);

        handler.mark(true);
        handler.wait(10);
        handler.poke();
        handler.wait(10);
        handler.poke();

        uint256 p3 = Vat(bank).par();
        assertLt(p3, p2);

        uint256 minPar = handler.minPar();
        assertLt(minPar, p1);
    }
}
