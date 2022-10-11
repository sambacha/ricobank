import { expect as want } from 'chai'

import * as hh from 'hardhat'
// @ts-ignore
import { ethers } from 'hardhat'
const { hexZeroPad } = ethers.utils
import { smock } from '@defi-wonderland/smock'

import { b32, snapshot, revert, curb_ramp } from './helpers'
import { fail, mine, wad, ray, rad, apy, send, BANKYEAR, U256_MAX } from 'minihat'
const debug = require('debug')('rico:test')

const dpack = require('@etherpacks/dpack')

const chai = require('chai')
chai.use(smock.matchers)
const i0 = Buffer.alloc(32) // ilk 0 id
const wtag = b32('WETHUSD')
const bn2b32 = (bn) => hexZeroPad(bn.toHexString(), 32)
const gettime = async () => {
    const blocknum = await ethers.provider.getBlockNumber()
    return (await ethers.provider.getBlock(blocknum)).timestamp
}

describe('vow / liq liquidation lifecycle', () => {
  let ali, bob, cat
  let ALI, BOB, CAT
  let RICO, RISK, WETH
  let vat; let vat_type
  let vow
  let flower; let flower_type
  let setter; let setter_type
  let vault
  let fb
  let poolId_weth_rico
  let poolId_risk_rico
  before(async () => {
    [ali, bob, cat] = await ethers.getSigners();
    [ALI, BOB, CAT] = [ali, bob, cat].map(signer => signer.address)

    debug('packs')
    const pack = await hh.run('deploy-ricobank', { mock: 'true' })
    const dapp = await dpack.load(pack, ethers, ali)

    flower_type = await smock.mock('BalancerFlower', { signer: ali })
    vat_type = await smock.mock('Vat', { signer: ali })

    vault = dapp.vault
    vow = dapp.vow
    RICO = dapp.rico
    RISK = dapp.risk
    WETH = dapp.weth
    fb = dapp.feedbase

    vat = await vat_type.deploy()
    flower = await flower_type.deploy()
    setter_type = await ethers.getContractFactory('FeeSetter')
    setter = await setter_type.deploy()

    // reset initial settings to use mocks
    debug('vat link ward')
    await send(vat.ward, vow.address, true)
    await send(vat.link, b32('feeds'), fb.address);
    await send(vat.link, b32('rico'), RICO.address);
    await send(vow.link, b32('flow'), flower.address)
    await send(vow.link, b32('vat'), vat.address)
    await send(vow.ward, flower.address, true)
    await send(RICO.ward, vat.address, true)

    debug('deposit')
    await send(WETH.deposit, { value: ethers.utils.parseEther('6000.0') })
    await send(RISK.mint, ALI, wad(10000))
    await send(WETH.approve, vat.address, U256_MAX)

    debug('vat init')
    await send(vat.init, i0, WETH.address, ALI, wtag)

    await send(vat.file, b32('ceil'), rad(10000))
    await send(vat.filk, i0, b32('line'), rad(10000))
    await send(vat.filk, i0, b32('liqr'), ray(1))
    await send(vat.filk, i0, b32('chop'), ray(1.1))

    debug('vow file, ramp, approve')
    await curb_ramp(vow, RISK, { vel: wad(1), rel: wad(0.001), bel: 0, cel: 60, del: 0})

    await send(vow.grant, WETH.address)

    await send(vow.grant, RICO.address)
    await send(vow.grant, RISK.address)

    const t1 = await gettime()
    await send(fb.push, wtag, bn2b32(ray(1)), t1 + 2 * BANKYEAR)
    await send(vat.ward, setter.address, true)
    await send(setter.set_fee, vat.address, i0, apy(1.05))
    await send(vat.frob, i0, ALI, wad(100), wad(0))
    await send(vat.frob, i0, ALI, wad(0), wad(99))

    debug('rico exit')
    const bal = await RICO.balanceOf(ALI)
    want(bal.toString()).equals(wad(99).toString())
    const safe1 = await vat.callStatic.safe(i0, ALI)
    want(safe1).eq(2)

    await send(WETH.connect(cat).deposit, { value: ethers.utils.parseEther('7000.0') })
    await send(WETH.connect(cat).approve, vat.address, U256_MAX)
    await send(vat.connect(cat).frob, i0, CAT, wad(4001), wad(4000))
    await send(RICO.connect(cat).transfer, ALI, wad(4000))

    debug('token approves')
    await send(WETH.approve, vault.address, U256_MAX)
    await send(RICO.approve, vault.address, U256_MAX)
    await send(RISK.approve, vault.address, U256_MAX)

    // read pool ids from original flow rather than mock
    poolId_weth_rico = await dapp.flow.pools(WETH.address, RICO.address)
    poolId_risk_rico = await dapp.flow.pools(RISK.address, RICO.address)

    const weth_rico_tokens = [{token: WETH, amountIn: wad(2000)},
                              {token: RICO, amountIn: wad(2000)}]
    const risk_rico_tokens = [{token: RISK, amountIn: wad(2000)},
                              {token: RICO, amountIn: wad(2000)}]
    const weth_rico_args = {
      balancer_pack: pack,
      token_settings: weth_rico_tokens,
      pool_id: poolId_weth_rico
    }
    const risk_rico_args = {
      balancer_pack: pack,
      token_settings: risk_rico_tokens,
      pool_id: poolId_risk_rico
    }
    await hh.run('join-weighted-bpool', weth_rico_args)
    await hh.run('join-weighted-bpool', risk_rico_args)

    await curb_ramp(vow, WETH, { vel: wad(1), rel: wad(0.001), bel: 0, cel: 600, del: 0 })
    await curb_ramp(vow, RICO, { vel: wad(1), rel: wad(0.001), bel: 0, cel: 600, del: 0 })

    // repeat set up for mocks
    await send(flower.setVault, vault.address)
    await send(flower.setPool, WETH.address, RICO.address, poolId_weth_rico)
    await send(flower.setPool, RICO.address, RISK.address, poolId_risk_rico)
    await send(flower.setPool, RISK.address, RICO.address, poolId_risk_rico)
    await send(flower.approve_gem, RICO.address)
    await send(flower.approve_gem, RISK.address)
    await send(flower.approve_gem, WETH.address)

    await snapshot(hh)
  })
  beforeEach(async () => {
    await revert(hh)
  })

  describe('bail urns', () => {
    beforeEach(async () => {
      flower.flow.reset()
    })
    it('vow 1yr not safe bail', async () => {
      await mine(hh, BANKYEAR)
      await send(vow.keep, [i0])

      const safe2 = await vat.callStatic.safe(i0, ALI)
      want(safe2).eq(0)

      const sin0 = await vat.sin(vow.address)
      const gembal0 = await WETH.balanceOf(flower.address)
      const vow_rico0 = await RICO.balanceOf(vow.address)
      want(sin0.eq(0)).true
      want(gembal0.eq(0)).true
      want(vow_rico0.eq(0)).true

      debug('bail')
      await send(vow.bail, i0, ALI)

      debug('end vals')
      const [ink, art] = await vat.urns(i0, ALI)
      const sin1 = await vat.sin(vow.address)
      const gembal1 = await WETH.balanceOf(flower.address)
      const vow_rico1 = await RICO.balanceOf(vow.address)
      want(ink.eq(0)).true
      want(art.eq(0)).true
      want(sin1.gt(0)).true
      want(vow_rico1.gt(0)).true
      want(gembal1.eq(0)).true
      want(flower.flow).to.have.been.called
    })

    it('when safe', async () => {
      await fail('ErrSafeBail', vow.bail, i0, ALI)
      want(flower.flow).to.have.callCount(0)

      const sin0 = await vat.sin(vow.address)
      const gembal0 = await WETH.balanceOf(flower.address)
      want(sin0.eq(0)).true
      want(gembal0.eq(0)).true

      await mine(hh, BANKYEAR)
      debug('bail success')
      await send(vow.bail, i0, ALI)
      debug('bail fail')
      await fail('ErrSafeBail', vow.bail, i0, ALI)
      want(flower.flow).to.have.been.called
    })
  })

  describe('keep', () => {
    beforeEach(async () => {
      flower.flow.reset()
      vat.heal.reset()
    })
    it('vow 1yr drip flap', async () => {
      const initial_total = await RICO.totalSupply()
      await mine(hh, BANKYEAR);
      await send(vow.keep, [i0]);
      const final_total = await RICO.totalSupply()
      want(flower.flow).to.have.been.called
      want(final_total.gt(initial_total)).true
      // minted 4099, fee is 1.05. 0.05*4099 as no surplus buffer
      want(final_total - initial_total).within(parseInt(wad(204.94).toString()), parseInt(wad(204.96).toString()))
    })
    it('vow 1yr drip flop', async () => {
      await mine(hh, BANKYEAR)
      await send(vow.bail, i0, ALI)

      await send(vow.keep, [i0])
      want(flower.flow).to.have.been.called
      want(vat.heal).to.have.been.called
    })

    describe('rate limiting', () => {
      it('flop absolute rate', async () => {
        const risk_supply_0 = await RISK.totalSupply()
        await send(setter.set_fee, vat.address, i0, apy(2))
        await curb_ramp(vow, RISK, { vel: wad(0.001), rel: wad(1000000), bel: 0, cel: 1000, del: 0})
        await mine(hh, BANKYEAR);
        await send(vow.bail, i0, CAT)
        await send(vow.keep, [i0])
        const risk_supply_1 = await RISK.totalSupply()
        await mine(hh, 500)
        await send(vow.keep, [i0])
        const risk_supply_2 = await RISK.totalSupply()

        // should have had a mint of the full vel*cel and then half vel*cel
        const mint1 = risk_supply_1 - risk_supply_0
        const mint2 = risk_supply_2 - risk_supply_1
        want(mint1).within(parseInt(wad(0.99).toString()), parseInt(wad(1.01).toString()))
        want(mint2).within(parseInt(wad(0.49).toString()), parseInt(wad(0.51).toString()))
      })

      it('flop relative rate', async () => {
        const risk_supply_0 = await RISK.totalSupply()
        await send(setter.set_fee, vat.address, i0, apy(2))
        // for same results as above the rel rate is set to 1 / risk supply * vel used above
        await curb_ramp(vow, RISK, { vel: wad(1000000), rel: wad(0.0000001), bel: 0, cel: 1000 })
        await mine(hh, BANKYEAR);
        await send(vow.bail, i0, CAT)
        await send(vow.keep, [i0])
        const risk_supply_1 = await RISK.totalSupply()
        await mine(hh, 500)
        await send(vow.keep, [i0])
        const risk_supply_2 = await RISK.totalSupply()

        // should have had a mint of the full vel*cel and then half vel*cel
        const mint1 = risk_supply_1 - risk_supply_0
        const mint2 = risk_supply_2 - risk_supply_1
        want(mint1).within(parseInt(wad(0.999).toString()), parseInt(wad(1.000).toString()))
        want(mint2).within(parseInt(wad(0.497).toString()), parseInt(wad(0.510).toString()))
      })
    })
  })

  describe('end to end', () => {
    beforeEach(async () => {
      flower.flow.reset()
      vat.heal.reset()
      flower.flow.reset()
    })

    it('all actions', async () => {
      // run a flap and ensure risk is burnt
      const risk_initial_supply = await RISK.totalSupply()
      await mine(hh, BANKYEAR)
      await send(vow.keep, [i0])
      await mine(hh, 60)
      flower.flow.reset()
      await send(vow.keep, [i0]) // call again to burn risk given to vow the first time
      const risk_post_flap_supply = await RISK.totalSupply()
      want(flower.flow).to.have.been.called
      want(risk_post_flap_supply.lt(risk_initial_supply)).true

      // confirm bail trades the weth for rico
      const vow_rico_0 = await RICO.balanceOf(vow.address)
      const vat_weth_0 = await WETH.balanceOf(vat.address)
      await send(vow.bail, i0, ALI)
      const vow_rico_1 = await RICO.balanceOf(vow.address)
      const vat_weth_1 = await WETH.balanceOf(vat.address)
      want(vow_rico_1.gt(vow_rico_0)).true
      want(vat_weth_0.gt(vat_weth_1)).true
      want(flower.flow).to.have.been.called

      // although the keep joins the rico sin is still greater due to fees so we flop
      await send(vow.keep, [i0])
      want(flower.flow).to.have.been.called
      // now vow should hold more rico than anti tokens
      const sin = await vat.sin(vow.address)
      const vow_rico = await RICO.balanceOf(vow.address)
      want(vow_rico * 10**27 > sin)
    })
  })
})
