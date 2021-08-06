module.exports = async function ({ ethers, getNamedAccounts, deployments }) {
    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()
    const cdzToken = await ethers.getContract("CDzToken")
    const cdzAsDeployer = await ethers.getContract("CDzToken", deployer)

    const perBlock = "18000000000000000000"             // 18 * 1e18
    const rewardTotal = "15552000000000000000000000"    // 15552000 * 1e18 
    const startBlock = "9292680"
    const endBlock = "10156680"

    const { address } = await deploy("LaunchPool", {
        from: deployer,
        log: true,
        args: [cdzToken.address, perBlock, startBlock, endBlock],
        deterministicDeployment: false
    })

    let poolBal = await cdzToken.balanceOf(address)
    if (poolBal.toString() === "0") {
        await (await cdzAsDeployer["mint(address,uint256)"](address, rewardTotal)).wait()
    }
    poolBal = await cdzToken.balanceOf(address)
    console.log("Transfer CDzToken to launch pool amount:",rewardTotal, "balance:", poolBal.toString())


    let pools = [
        {
            name: "CAKE",
            address: "0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82",
            allocPoint: "150"
        },
        {
            name:"BAKE",
            address: "0xE02dF9e3e622DeBdD69fb838bB799E3F168902c5",
            allocPoint:"150"
        },
        {
            name:"XVS",
            address: "0xcf6bb5389c92bdda8a3747ddb454cb7a64626c63",
            allocPoint:"150"
        },
        {
            name:"DOGE",
            address: "0xbA2aE424d960c26247Dd6c32edC70B295c744C43",
            allocPoint:"100"
        },
        {
            name: "WBNB",
            address: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
            allocPoint: "50"
        },
        {
            name:"LP-CAKE/WBNB",
            address: "0x0eD7e52944161450477ee417DE9Cd3a859b14fD0",
            allocPoint:"200"
        },
        {
            name:"LP-BUSD/WBNB",
            address: "0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16",
            allocPoint:"200"
        },
        {
            name:"LP-USDT/WBNB",
            address: "0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE",
            allocPoint:"200"
        },
        {
            name:"LP-BTCB/WBNB",
            address: "0x61EB789d75A95CAa3fF50ed7E47b96c132fEc082",
            allocPoint:"200"
        },
        {
            name:"LP-ETH/WBNB",
            address: "0x74E4716E431f45807DCF19f284c7aA99F18a4fbc",
            allocPoint:"200"
        }
    ]

    const launchPool = await ethers.getContract("LaunchPool")
    for (const p of pools) {
        await(await launchPool.add(p.allocPoint, p.address, true)).wait()
        console.log("Add pool:", p.name, "address:", p.address, "alloc_point:", p.allocPoint)
    }

    module.exports.tags = ["LaunchPool"]
    module.exports.dependencies = ["CDzToken"]
}
