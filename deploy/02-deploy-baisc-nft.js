const { verify } = require("../utils/verify")
const { network } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()

    const arguments = []

    const basicNft = await deploy("BasicNft", {
        from: deployer,
        args: arguments,
        log: true,
        waitConfirmation: network.config.blockConfirmations,
    })

    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...")
        await verify(basicNft.address, arguments)
    }
}
module.exports.tags = ["all", "basicnft"]
