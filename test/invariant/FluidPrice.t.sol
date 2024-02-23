// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {Gem} from "../../lib/gemfab/src/gem.sol";
import {Vat} from "../../src/vat.sol";
import {Vox} from "../../src/vox.sol";
import {BaseHelper} from "../BaseHelper.sol";
import {ERC20Handler} from "./handlers/ERC20Handler.sol";

// Uses single WETH ilk and modifies WETH and RICO price during run
contract InvariantFluidPrice is Test, BaseHelper {
    ERC20Handler handler;
    uint256 cap;
    uint256 icap;
    Vat vat;
    Vox vox;
    Gem rico;

    function setUp() external {
        handler = new ERC20Handler();
        bank = handler.bank();
        rico = handler.rico();
        vat = Vat(bank);
        vox = Vox(bank);
        cap = vox.cap();
        icap = rinv(cap);

        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](10);
        selectors[0] = ERC20Handler.frob.selector;
        selectors[1] = ERC20Handler.frob.selector; // add frob twice to double probability
        selectors[2] = ERC20Handler.bail.selector;
        selectors[3] = ERC20Handler.keep.selector;
        selectors[4] = ERC20Handler.drip.selector;
        selectors[5] = ERC20Handler.poke.selector;
        selectors[6] = ERC20Handler.mark.selector;
        selectors[7] = ERC20Handler.wait.selector;
        selectors[8] = ERC20Handler.date.selector;
        selectors[9] = ERC20Handler.move.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    // all invariant tests combined for efficiency
    function invariant_core() external {
        uint256 sup = rico.totalSupply();
        uint256 joy = vat.joy();
        uint256 debt = vat.debt();
        uint256 rest = vat.rest();
        uint256 sin = vat.sin();
        uint256 tart = vat.ilks(WETH_ILK).tart;
        uint256 rack = vat.ilks(WETH_ILK).rack;
        uint256 line = vat.ilks(WETH_ILK).line;
        uint256 liqr = uint256(vat.geth(WETH_ILK, "liqr", empty));
        uint256 way = vox.way();
        uint256 weth_val = handler.localWeth() * handler.weth_ref_max() / handler.minPar();

        // debt invariant
        assertEq(joy + sup, debt);

        // tart invariant. compare as RADs. unchecked - ok if both are equally negative
        unchecked {
            assertEq(tart * rack - rest, RAY * (sup + joy) - sin);
        }
        assertLt(tart * RAY, line);

        // actors ink + weth should be constant outside of liquidations and frobs which benefit a different urn,
        // actors can't steal from others CDPs
        for (uint256 i = 0; i < handler.NUM_ACTORS(); ++i) {
            address actor = handler.actors(i);
            int256 ink = int256(_ink(WETH_ILK, actor));
            int256 weth = int256(Gem(WETH).balanceOf(actor));
            int256 off = handler.ink_offset(actor);
            int256 init = int256(handler.ACTOR_WETH());
            assertEq(ink + weth, init + off);
        }

        // assert limit on total possible RICO drawn
        assertLt(sup, rdiv(weth_val, liqr));

        // way stays within bounds given owner does not file("cap")
        assertLe(way, cap);
        assertGe(way, icap);
    }
}
