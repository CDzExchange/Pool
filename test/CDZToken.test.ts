import { ethers } from "hardhat";
import { expect } from "chai";
import exp = require("constants");
import {advanceBlock} from "./utilities";

describe("CDZToken", function() {
    before(async function() {
        this.CDzToken = await ethers.getContractFactory("CDzToken")
        this.signers = await ethers.getSigners()
        this.alice = this.signers[0]
        this.bob = this.signers[1]
        this.carol = this.signers[2]
    })

    beforeEach(async function() {
        this.cdz = await this.CDzToken.deploy()
        advanceBlock()
    });

    it("should have correct name and symbol and decimal", async function () {
        const name = await this.cdz.name()
        const symbol = await this.cdz.symbol()
        const decimal = await this.cdz.decimals()
        expect(name, "CDzToken")
        expect(symbol, "CDZ")
        expect(decimal, "18")
    })

    it("should only allow owner to mint token", async function () {
        await this.cdz['mint(address,uint256)'](this.alice.address, 100);
        await this.cdz['mint(address,uint256)'](this.bob.address, 1000)
        await expect(this.cdz.connect(this.bob)['mint(address,uint256)'](this.carol.address, "1000", { from: this.bob.address })).to.be.revertedWith(
            "Ownable: caller is not the owner"
        )
        const totalSupply = await this.cdz.totalSupply()
        const aliceBal = await this.cdz.balanceOf(this.alice.address)
        const bobBal = await this.cdz.balanceOf(this.bob.address)
        const carolBal = await this.cdz.balanceOf(this.carol.address)
        expect(totalSupply).to.equal("1100")
        expect(aliceBal).to.equal("100")
        expect(bobBal).to.equal("1000")
        expect(carolBal).to.equal("0")
    })

    it("should supply token transfers properly", async function () {
        await this.cdz['mint(address,uint256)'](this.alice.address, 100);
        await this.cdz['mint(address,uint256)'](this.bob.address, 1000)
        await this.cdz.transfer(this.carol.address, "10")
        await this.cdz.connect(this.bob).transfer(this.carol.address, "100", {
            from: this.bob.address,
        })
        const totalSupply = await this.cdz.totalSupply()
        const aliceBal = await this.cdz.balanceOf(this.alice.address)
        const bobBal = await this.cdz.balanceOf(this.bob.address)
        const carolBal = await this.cdz.balanceOf(this.carol.address)
        expect(totalSupply, "1100")
        expect(aliceBal, "90")
        expect(bobBal, "900")
        expect(carolBal, "110")
    })

    it("should fail if you try to do bad transfers", async function () {
        await this.cdz['mint(address,uint256)'](this.alice.address, 100)
        await expect(this.cdz.transfer(this.carol.address, "110")).to.be.revertedWith("BEP20: transfer amount exceeds balance")
        await expect(this.cdz.connect(this.bob).transfer(this.carol.address, "1", { from: this.bob.address })).to.be.revertedWith(
            "BEP20: transfer amount exceeds balance"
        )
    })
});
