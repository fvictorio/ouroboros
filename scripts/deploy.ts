import { network } from "hardhat";
import { keccak256, toBytes } from "viem";

const { viem, provider } = await network.connect();

const salt = keccak256(toBytes("ouroboros"))

const deployer = await viem.deployContract("Deployer")

await deployer.write.deploy([salt])

const ouroAddress = await deployer.read.ouro();
const borosAddress = await deployer.read.boros();

console.log("Deployer.ouro():", ouroAddress)
console.log("Deployer.boros():", borosAddress)

const ouro = await viem.getContractAt("Ouro", ouroAddress)
const boros = await viem.getContractAt("Boros", borosAddress)

console.log("Boros.getOuro():", await boros.read.getOuro())
console.log("Ouro.getBoros():", await ouro.read.getBoros())