// SPDX-License-Identifier: AGPL-3.0-or-later

// Copyright (C) 2021-2024 halys

pragma solidity ^0.8.19;
import { Gem }  from "../lib/gemfab/src/gem.sol";
import { Feedbase } from "../lib/feedbase/src/Feedbase.sol";
import { Bank } from "./bank.sol";

contract File is Bank {
    uint constant _CAP_MAX = 1000000072964521287979890107; // ~10x/yr
    uint constant _REL_MAX = 100 * RAY / BANKYEAR; // ~100x/yr
    function CAP_MAX() external pure returns (uint) {return _CAP_MAX;}
    function REL_MAX() external pure returns (uint) {return _REL_MAX;}

    function file(bytes32 key, bytes32 val) external payable onlyOwner _flog_ {
        VatStorage storage vatS = getVatStorage();
        VowStorage storage vowS = getVowStorage();
        VoxStorage storage voxS = getVoxStorage();
        BankStorage storage bankS = getBankStorage();
        uint _val = uint(val);

               if (key == "rico") { bankS.rico = Gem(address(bytes20(val)));
        } else if (key == "fb") { bankS.fb = Feedbase(address(bytes20(val)));
        } else if (key == "ceil") { vatS.ceil = _val;
        } else if (key == "par") { vatS.par = _val;
        } else if (key == "rel") {
            must(_val, 0, _REL_MAX);
            vowS.ramp.rel = _val;
        } else if (key == "bel") {
            must(_val, 0, block.timestamp);
            vowS.ramp.bel = _val;
        } else if (key == "cel") { vowS.ramp.cel = _val;
        } else if (key == "wel") {
            must(_val, 0, RAY);
            vowS.ramp.wel = _val;
        } else if (key == "loot") {
            must(_val, 0, RAY);
            vowS.loot = _val;
        } else if (key == "plot.pep") { vowS.plot.pep = _val;
        } else if (key == "plat.pep") { vowS.plat.pep = _val;
        } else if (key == "plot.pop") {
            must(_val, RAY / 10, 10 * RAY);
            vowS.plot.pop = _val;
        } else if (key == "plat.pop") {
            must(_val, RAY / 10, 10 * RAY);
            vowS.plat.pop = _val;
        } else if (key == "plot.pup") { vowS.plot.pup = int(_val);
        } else if (key == "plat.pup") { vowS.plat.pup = int(_val);
        } else if (key == "rudd.src") { vowS.rudd.src = address(bytes20(val));
        } else if (key == "rudd.tag") { vowS.rudd.tag = val;
        } else if (key == "risk") { vowS.risk = Gem(address(bytes20(val)));
        } else if (key == "tip.src") { voxS.tip.src = address(bytes20(val));
        } else if (key == "tip.tag") { voxS.tip.tag = val;
        } else if (key == "how") {
            must(_val, RAY, type(uint).max);
            voxS.how = _val;
        } else if (key == "cap") {
            must(_val, RAY, _CAP_MAX);
            voxS.cap = _val;
        } else if (key == "tau") {
            must(_val, block.timestamp, type(uint).max);
            voxS.tau = _val;
        } else if (key == "way") {
            must(_val, rinv(voxS.cap), voxS.cap);
            voxS.way = _val;
        } else revert ErrWrongKey();

        emit NewPalm0(key, val);
    }

    function rico() external view returns (Gem) {return getBankStorage().rico;}
    function fb() external view returns (Feedbase) {return getBankStorage().fb;}
}
