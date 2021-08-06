import {ethers} from "hardhat";
import {expect} from "chai";
import {advanceBlock, advanceBlockAdd, advanceBlockTo} from "./utilities";
import exp = require("constants");

describe ("LaunchPool", function () {
    before(async function () {
        this.PerBlock = 100
        this.StartBlock = 1000
        this.EndBlock = 2000

        this.signers = await ethers.getSigners()
        this.alice = this.signers[0]
        this.bob = this.signers[1]

        this.CDzToken = await ethers.getContractFactory("CDzToken")
        this.LaunchPool = await ethers.getContractFactory("LaunchPool")
        this.BEP20Mock = await ethers.getContractFactory("BEP20Mock", this.minter)
    })

    beforeEach(async function() {
        // deploy cdz token
        this.cdz = await this.CDzToken.deploy()
        await this.cdz.deployed()

        // deploy master chef
        this.chef = await this.LaunchPool.deploy(this.cdz.address, this.PerBlock, this.StartBlock, this.EndBlock)
        await this.chef.deployed()

        // mint cdz to alice and bob
        await this.cdz['mint(address,uint256)'](this.chef.address, 100000)
    })

    it("Should set correct state variables", async function () {
        const cdz = await this.chef.cdz()
        const perBlock = await this.chef.cdzPerBlock()
        const startBlock = await this.chef.startBlock()
        const endBlock = await this.chef.endBlock()

        expect(cdz).to.equal(this.cdz.address)
        expect(perBlock).to.equal(this.PerBlock)
        expect(startBlock).to.equal(this.StartBlock)
        expect(endBlock).to.equal(this.EndBlock)
    })

    describe("LpToken pool", function () {
        beforeEach(async function (){
            // deploy BEP20 Token
            this.lpToken= await this.BEP20Mock.deploy("lpToken 1", "LP1", 100000000)
            await this.lpToken.deployed()

            await this.lpToken.transfer(this.alice.address, 10000)
            await this.lpToken.transfer(this.bob.address, 10000)

            await this.lpToken.connect(this.alice).approve(this.chef.address, 10000)
            await this.lpToken.connect(this.bob).approve(this.chef.address, 10000)

            await this.chef.add(100, this.lpToken.address, true)
        })
        
        it("Should add pool ok", async function () {
            const poolLength = await this.chef.poolLength()
            const poolInfo = await this.chef.poolInfo(0)
            const lpToken = poolInfo["lpToken"]
            const allocPoint = poolInfo["allocPoint"]
            const accCDZPerShare = poolInfo["accCDZPerShare"]
            const totalAllocPoint = await this.chef.totalAllocPoint()
            expect(poolLength).to.equal(1)
            expect(lpToken).to.equal(this.lpToken.address)
            expect(allocPoint).to.equal(100)
            expect(accCDZPerShare).to.equal(0)
            expect(totalAllocPoint).to.equal(100)
        })

       it("Should deposit and calculate pending ok", async function () {
           await advanceBlockTo(1000)
           await this.chef.connect(this.alice).deposit(0, 300)
           await this.chef.connect(this.bob).deposit(0, 200)
           await advanceBlockAdd(10)
           const alicePending = await this.chef.pendingCDZ(0, this.alice.address)
           const bobPending = await this.chef.pendingCDZ(0, this.bob.address)
           // (1 * 100) + ((10 * 50 * 300) / 500) - 1 = 349
           expect(alicePending).to.equal(699)
           // (10 * 100 * 200) / 500 = 200
           expect(bobPending).to.equal(400)
       })

       it("Should harvest revert when not reach the end block", async function () {
           await this.chef.connect(this.alice).deposit(0, 400)
           await advanceBlockAdd(10)
           await expect(this.chef.connect(this.alice).harvest(0)).to.be.revertedWith(
               "harvest: not reach the end block number"
           )
       })

       it("Should withdraw ok and loss reward", async function () {
           await this.chef.connect(this.bob).deposit(0, 400)
           await advanceBlockAdd(10)
           const pending1 = await this.chef.pendingCDZ(0, this.bob.address)
           await this.chef.connect(this.bob).withdraw(0, 200)
           const pending2 = await this.chef.pendingCDZ(0, this.bob.address)
           await this.chef.connect(this.bob).withdraw(0, 200)
           const pending3 = await this.chef.pendingCDZ(0, this.bob.address)
           const bal = await this.lpToken.balanceOf(this.bob.address)
           expect(pending1).to.equal(1000)
           expect(pending2).to.equal(550)
           expect(pending3).to.equal(0)
       })
       //
       // it("Should withdrawAndHarvest ok", async function () {
       //     await this.chef.connect(this.carol).deposit(1, 400)
       //     await this.chef.connect(this.carol).withdrawAndHarvest(1, 400)
       //     const lpBal = await this.lpToken.balanceOf(this.carol.address)
       //     const cdzBal = await this.cdz.balanceOf(this.carol.address)
       //     expect(lpBal).to.equal(1000)
       //     expect(cdzBal).to.equal(50)
       // })
       //
       // it ("Should emergencyWithdraw ok", async function () {
       //     await this.chef.connect(this.carol).deposit(1, 400)
       //     await this.chef.connect(this.carol).emergencyWithdraw(1)
       //     const lpBal = await this.lpToken.balanceOf(this.carol.address)
       //     const cdzBal = await this.cdz.balanceOf(this.carol.address)
       //     expect(lpBal).to.equal(1000)
       //     expect(cdzBal).to.equal(0)
       // })
    })
    
})
