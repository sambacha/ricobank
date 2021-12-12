import { expect as want } from 'chai'

import * as hh from 'hardhat'
import { ethers } from 'hardhat'

import { b32, snapshot, revert } from './helpers'
import { mine, wad, send } from 'minihat'

describe('RicoFlowerV1 balancer interaction', () => {
  let ali, bob, cat
  let ALI, BOB, CAT
  let RICO, RISK, WETH; let gem_type
  let flower; let flower_type;
  let vault
  let poolId_weth_rico
  let poolId_risk_rico
  before(async () => {
    [ali, bob, cat] = await ethers.getSigners();
    [ALI, BOB, CAT] = [ali, bob, cat].map(signer => signer.address)
    const gem_artifacts = require('../lib/gemfab/artifacts/sol/gem.sol/Gem.json')
    gem_type = ethers.ContractFactory.fromSolidity(gem_artifacts, ali)
    flower_type = await ethers.getContractFactory('RicoFlowerV1', ali)

    flower = await flower_type.deploy();
    RICO = await gem_type.deploy('Rico', 'RICO')
    RISK = await gem_type.deploy('Rico Riskshare', 'RISK')
    WETH = await gem_type.deploy('Wrapped Ether', 'WETH')

    await send(WETH.mint, ALI, wad(10000))
    await send(RICO.mint, ALI, wad(10000))
    await send(RISK.mint, ALI, wad(10000))

    // run the deploy balancer task which deploys balancer vault and creates pools
    let task_args = {WETH: WETH, RICO: RICO, RISK: RISK}
    let task_result = await hh.run('deploy-balancer', task_args)
    vault = task_result.vault
    poolId_weth_rico = task_result.poolId_weth_rico
    poolId_risk_rico = task_result.poolId_risk_rico

    await send(flower.file_ramp, WETH.address, {vel:wad(1), rel:wad(0.001), bel:0, cel:600})
    await send(flower.file_ramp, RICO.address, {vel:wad(1), rel:wad(0.001), bel:0, cel:600})
    await send(flower.file, b32('rico'), RICO.address)
    await send(flower.file, b32('risk'), RISK.address)
    await send(flower.setVault, vault.address)
    await send(flower.setPool, WETH.address, RICO.address, poolId_weth_rico)
    await send(flower.setPool, RICO.address, RISK.address, poolId_risk_rico)
    await send(flower.setPool, RISK.address, RICO.address, poolId_risk_rico)
    await send(flower.reapprove)
    await send(flower.approve_gem, WETH.address)

    await snapshot(hh)
  })
  beforeEach(async () => {
    await revert(hh)
  })

  describe('rate limiting', () => {
    describe('flap', () => {
      it('absolute rate', async () => {
        await send(flower.file_ramp, RICO.address, {vel:wad(0.1), rel:wad(1000), bel:0, cel:1000})
        await send(RICO.transfer, flower.address, wad(50))
        const rico_liq_0 = await vault.getPoolTokens(poolId_risk_rico)
        // consume half the allowance
        await send(flower.flap, 0)
        const rico_liq_1 = await vault.getPoolTokens(poolId_risk_rico)
        // recharge by a quarter of capacity so should sell 75%
        await send(RICO.transfer, flower.address, wad(100))
        await mine(hh, 250)
        await send(flower.flap, 0)
        const rico_liq_2 = await vault.getPoolTokens(poolId_risk_rico)

        const sale_0 = rico_liq_1[1][1] - rico_liq_0[1][1]
        const sale_1 = rico_liq_2[1][1] - rico_liq_1[1][1]
        want(sale_0).closeTo(parseInt(wad(50).toString()), parseInt(wad(0.5).toString()))
        want(sale_1).closeTo(parseInt(wad(75).toString()), parseInt(wad(0.5).toString()))
      })
      it('relative rate', async () => {
        await send(flower.file_ramp, RICO.address, {vel:wad(10000), rel:wad(0.00001), bel:0, cel:1000})
        await send(RICO.transfer, flower.address, wad(50))
        const rico_liq_0 = await vault.getPoolTokens(poolId_risk_rico)
        // consume half the allowance
        await send(flower.flap, 0)
        const rico_liq_1 = await vault.getPoolTokens(poolId_risk_rico)
        // recharge by a quarter of capacity and give excess funds
        await send(RICO.transfer, flower.address, wad(100))
        await mine(hh, 250)
        await send(flower.flap, 0)
        const rico_liq_2 = await vault.getPoolTokens(poolId_risk_rico)

        const sale_0 = rico_liq_1[1][1] - rico_liq_0[1][1]
        const sale_1 = rico_liq_2[1][1] - rico_liq_1[1][1]
        want(sale_0).closeTo(parseInt(wad(50).toString()), parseInt(wad(0.5).toString()))
        want(sale_1).closeTo(parseInt(wad(75).toString()), parseInt(wad(0.5).toString()))
      })
    })
  })
})
