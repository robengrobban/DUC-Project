import { Web3 } from 'web3';
import { promises as fs } from 'fs';
const network = "ws://192.168.174.130:8546";

const web3 = new Web3(network);
const wallet = web3.eth.accounts.wallet;
const account = web3.eth.accountProvider.privateKeyToAccount('0xd0a5e7b124eb5c1d327f7c19c988bb57979637043e52db48683da62900973b96');
web3.eth.defaultAccount = account.address;
wallet.add(account);
//console.log(wallet);

const abi = JSON.parse(await fs.readFile("contracts/Contract.abi", "utf-8"));
const contract_address = await fs.readFile("contracts/Contract.address", "utf-8");

const contract = new web3.eth.Contract(abi, contract_address);
contract.defaultAccount = account.address;

contract.events.RegisteredCPO({fromBlock:'latest'}).on('data', log => {
    console.log("CPO: ", log);
});
contract.events.RegisteredCS({fromBlock:'latest'}).on('data', log => {
    console.log("CS: ", log);
});

let registered = await contract.methods.isRegistered(account.address).call();
//console.log(registered);

let response = await contract.methods.registerCPO(account.address).send();
//console.log(response);

response = await contract.methods.registerCS(account.address, '0x2C2C18Fe7E216447231198E039d2997615620eD7').send();
//console.log(response);