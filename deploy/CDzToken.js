module.exports = async function ({ ethers, getNamedAccounts, deployments}) {
    const { deploy } = deployments
    const { deployer, dev } = await getNamedAccounts()

    await deploy("CDzToken", {
        from: deployer,
        log: true,
        deterministicDeployment: false,
    })

    module.exports.tags = ["CDzToken"]
}
