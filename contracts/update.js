import { Web3 } from 'web3';
import { promises as fs } from 'fs';
const network = "ws://192.168.174.129:8546";

const web3 = new Web3(network);
const wallet = web3.eth.accounts.wallet;
const account = web3.eth.accountProvider.privateKeyToAccount('0xed98532573c20603373c8d8ee9ca07b5d15e3e55e35e4ec9fa99183087bef3df');
wallet.add(account);
web3.defaultAccount = account;

async function read(name) {
    const address = await fs.readFile("contracts/address/"+name+".address", "utf-8");
    console.log("Reading...", name, address);
    return address;
}

async function deploy(name) {

    const abi = JSON.parse(await fs.readFile("contracts/abi/"+name+".abi", "utf-8"));
    const bytecode = "0x" + await fs.readFile("contracts/bin/"+name+".bin", "utf-8");
    
    const contract = new web3.eth.Contract(abi);
    contract.options.data = bytecode;
    const deployTX = contract.deploy();
    
    const gas = (await deployTX.estimateGas()) * web3.utils.toBigInt(2);
    
    console.log("Deploying...", name);
    const deployedContract = await deployTX.send({
        from: account.address, 
        gas: gas
    });
    
    const contract_address = deployedContract.options.address;
    console.log("Success...", contract_address);
    
    fs.writeFile("contracts/address/"+name+".address", contract_address, "utf-8");

    return contract_address;
}

async function connect(name, args) {
    console.log("Connecting...", name, "with", args)
    const abi = JSON.parse(await fs.readFile("contracts/abi/"+name+".abi", "utf-8"));
    const contract_address = await fs.readFile("contracts/address/"+name+".address", "utf-8");

    const contract = new web3.eth.Contract(abi, contract_address);
    contract.defaultAccount = account.address;

    return await contract.methods.set(
        args
    ).send();
}

async function connectMulti(name, ad1, ad2, ab3, ab4, ab5) {
    console.log("Connecting...", name, "with", ad1, ad2, ab3, ab4, ab5)
    const abi = JSON.parse(await fs.readFile("contracts/abi/"+name+".abi", "utf-8"));
    const contract_address = await fs.readFile("contracts/address/"+name+".address", "utf-8");

    const contract = new web3.eth.Contract(abi, contract_address);
    contract.defaultAccount = account.address;

    return await contract.methods.set(
        ad1,
        ad2,
        ab3,
        ab4,
        ab5
    ).send();
}

const contract_address = await read("Contract");
const entity_address = await read("Entity");
const deal_address = await read("Deal");
const connection_address = await read("Connection");
const rate_address = await read("Rate");
const charging_address = await deploy("Charging");

await connectMulti("Contract", entity_address, deal_address, connection_address, rate_address, charging_address);
await connect("Charging", contract_address);

console.log("Done");
process.exit();