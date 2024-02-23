// SPDX-License-Identifier: AGPL-3.0-or-later

// Copyright (C) 2021-2024 halys

pragma solidity ^0.8.19;

import {Gem} from "../../bank.sol";
import {HookMix} from "../hook.sol";

// hook that interprets ink as a single uint and dink as a single int.
contract ERC20Hook is HookMix {
    struct ERC20HookStorage {
        mapping(address u => uint256) inks; // amount
        Gem gem; // this ilk's gem
        uint256 liqr; // [ray] liquidation ratio
        Rudd rudd; // [obj] feed src,tag
        Plx plot; // [obj] discount exponent and offset
    }

    function getStorage(bytes32 i) internal pure returns (ERC20HookStorage storage hs) {
        bytes32 pos = keccak256(abi.encodePacked(i));
        assembly {
            hs.slot := pos
        }
    }

    error ErrTransfer();

    function ink(bytes32 i, address u) external view returns (bytes memory) {
        return abi.encode(getStorage(i).inks[u]);
    }

    function frobhook(FHParams calldata p) external payable returns (bool safer) {
        ERC20HookStorage storage hs = getStorage(p.i);

        // read dink as a single uint
        int256 dink = p.dink.length == 0 ? int256(0) : abi.decode(p.dink, (int256));

        // safer if locking ink and wiping art
        safer = dink >= 0 && p.dart <= 0;
        if (!safer && p.u != p.sender) revert ErrWrongUrn();

        // update balance before transfering tokens
        uint256 _ink = add(hs.inks[p.u], dink);
        hs.inks[p.u] = _ink;
        emit NewPalmBytes2("ink", p.i, bytes32(bytes20(p.u)), abi.encode(_ink));

        if (dink > 0) {
            // pull tokens from sender
            if (!hs.gem.transferFrom(p.sender, address(this), uint256(dink))) {
                revert ErrTransfer();
            }
        } else if (dink < 0) {
            // return tokens to urn holder
            if (!hs.gem.transfer(p.u, uint256(-dink))) {
                revert ErrTransfer();
            }
        }
    }

    function bailhook(BHParams calldata p) external payable returns (bytes memory) {
        ERC20HookStorage storage hs = getStorage(p.i);

        // tot is RAD, deal is RAY, so bank earns a WAD.
        // sell - sold collateral
        // earn - rico "earned" by bank in this liquidation
        uint256 full = hs.inks[p.u];
        uint256 sell;
        uint256 mash = rmash(p.deal, hs.plot.pep, hs.plot.pop, hs.plot.pup);
        uint256 earn = rmul(p.tot / RAY, mash);

        // clamp `sell` so bank only gets enough to underwrite urn.
        if (earn > p.bill) {
            sell = (full * p.bill) / earn;
            earn = p.bill;
        } else {
            sell = full;
        }
        vsync(p.i, earn, p.owed, 0);

        // update collateral balance
        unchecked {
            uint256 _ink = full - sell;
            hs.inks[p.u] = _ink;
            emit NewPalmBytes2("ink", p.i, bytes32(bytes20(p.u)), abi.encode(_ink));
        }

        // trade collateral with keeper for rico
        getBankStorage().rico.burn(p.keeper, earn);
        if (!hs.gem.transfer(p.keeper, sell)) revert ErrTransfer();

        return abi.encode(sell);
    }

    function safehook(bytes32 i, address u) external view returns (uint256 tot, uint256 cut, uint256 ttl) {
        ERC20HookStorage storage hs = getStorage(i);

        // total value of collateral == ink * price feed val
        (bytes32 val, uint256 _ttl) = getBankStorage().fb.pull(hs.rudd.src, hs.rudd.tag);
        uint256 _ink = hs.inks[u];
        tot = uint256(val) * _ink;
        cut = uint256(val) * rdiv(_ink, hs.liqr);
        ttl = _ttl;
    }

    function file(bytes32 key, bytes32 i, bytes32[] calldata xs, bytes32 val) external payable {
        ERC20HookStorage storage hs = getStorage(i);

        if (xs.length == 0) {
            if (key == "gem") {
                hs.gem = Gem(address(bytes20(val)));
            } else if (key == "src") {
                hs.rudd.src = address(bytes20(val));
            } else if (key == "tag") {
                hs.rudd.tag = val;
            } else if (key == "liqr") {
                must(uint256(val), RAY, type(uint256).max);
                hs.liqr = uint256(val);
            } else if (key == "pep") {
                hs.plot.pep = uint256(val);
            } else if (key == "pop") {
                hs.plot.pop = uint256(val);
            } else if (key == "pup") {
                hs.plot.pup = int256(uint256(val));
            } else {
                revert ErrWrongKey();
            }
            emit NewPalm1(key, i, val);
        } else {
            revert ErrWrongKey();
        }
    }

    function get(bytes32 key, bytes32 i, bytes32[] calldata xs) external view returns (bytes32) {
        ERC20HookStorage storage hs = getStorage(i);

        if (xs.length == 0) {
            if (key == "gem") return bytes32(bytes20(address(hs.gem)));
            else if (key == "src") return bytes32(bytes20(hs.rudd.src));
            else if (key == "tag") return hs.rudd.tag;
            else if (key == "liqr") return bytes32(hs.liqr);
            else if (key == "pep") return bytes32(hs.plot.pep);
            else if (key == "pop") return bytes32(hs.plot.pop);
            else if (key == "pup") return bytes32(uint256(hs.plot.pup));
            else revert ErrWrongKey();
        } else {
            revert ErrWrongKey();
        }
    }
}
