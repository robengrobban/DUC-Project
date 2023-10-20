import { Web3 } from 'web3';
import { promises as fs } from 'fs';
const network = "ws://192.168.174.129:8546";

const web3 = new Web3(network);
const wallet = web3.eth.accounts.wallet;
const account = web3.eth.accountProvider.privateKeyToAccount('0xed98532573c20603373c8d8ee9ca07b5d15e3e55e35e4ec9fa99183087bef3df');
wallet.add(account);

const abi = JSON.parse(await fs.readFile("contracts/Contract.abi", "utf-8"));
const bytecode = "0x" + await fs.readFile("contracts/Contract.bin", "utf-8");

const contract = new web3.eth.Contract(abi);
contract.options.data = bytecode;
const deployTX = contract.deploy();

const gas = await deployTX.estimateGas();

console.log("Deploying contract...")
const deployedContract = await deployTX.send({
    from: account.address, 
    gas: gas
});
console.log(deployedContract);

const contract_address = deployedContract.options.address;

fs.writeFile("contracts/Contract.address", contract_address, "utf-8");