import { Web3 } from 'web3';
import { promises as fs } from 'fs';
const network = "ws://192.168.174.129:8546";

const web3 = new Web3(network);
const wallet = web3.eth.accounts.wallet;
const account = web3.eth.accountProvider.privateKeyToAccount('0xed98532573c20603373c8d8ee9ca07b5d15e3e55e35e4ec9fa99183087bef3df'); // OWNER
web3.eth.defaultAccount = account.address;
wallet.add(account);

const abi = JSON.parse(await fs.readFile("contracts/abi/Oracle.abi", "utf-8"));
const contract_address = await fs.readFile("contracts/address/Oracle.address", "utf-8");

const contract = new web3.eth.Contract(abi, contract_address);
contract.defaultAccount = account.address;
