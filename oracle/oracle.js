import { Web3 } from 'web3';
import { promises as fs } from 'fs';
const network = "ws://192.168.174.129:8546";

const web3 = new Web3(network);
const account = web3.eth.accountProvider.privateKeyToAccount('0xb3357c2e53c1ef0099633f59be3e872cfc492337e89475dbc8cc6bef08bef0f9'); // ORACLE
web3.eth.defaultAccount = account.address;
web3.wallet.add(account);

//const abi = JSON.parse(await fs.readFile("contracts/Contract.abi", "utf-8"));
//const contract_address = await fs.readFile("contracts/Contract.address", "utf-8");

//const contract = new web3.eth.Contract(abi, contract_address);
//contract.defaultAccount = account.address;
