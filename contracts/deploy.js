import { Web3 } from 'web3';
import { promises as fs } from 'fs';
const network = "ws://192.168.174.129:8546";

const web3 = new Web3(network);
const wallet = web3.eth.accounts.wallet;
const account = web3.eth.accountProvider.privateKeyToAccount('0xed98532573c20603373c8d8ee9ca07b5d15e3e55e35e4ec9fa99183087bef3df');
wallet.add(account);
web3.defaultAccount = account;

async function deploy(name) {

    const abi = JSON.parse(await fs.readFile("contracts/abi/"+name+".abi", "utf-8"));
    const bytecode = "0x" + await fs.readFile("contracts/bin/"+name+".bin", "utf-8");
    
    const contract = new web3.eth.Contract(abi);
    contract.options.data = bytecode;
    const deployTX = contract.deploy();
    
    const gas = await deployTX.estimateGas();
    
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
    const abi = JSON.parse(await fs.readFile("contracts/abi/"+name+".abi", "utf-8"));
    const contract_address = await fs.readFile("contracts/address/"+name+".address", "utf-8");

    const contract = new web3.eth.Contract(abi, contract_address);
    contract.defaultAccount = account.address;

    return await contract.methods.set(
        args
    ).send();
}

await deploy("Contract-old.sol");

//const main_contract = await deploy("Contract");
//console.log(main_contract);

//const entity_contract = await deploy("Entity");
//console.log(entity_contract);


