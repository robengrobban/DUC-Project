import { Web3 } from 'web3'
import { promises as fs } from 'fs'

class Entity {

    address;
    secret;
    network;
    web3;

    wallet;
    account;

    contract;

    abi;
    contract_address;

    constructor(address, secret, network) {
        this.address = address;
        this.secret = secret;
        this.network = network;

        this.web3 = new Web3(this.network);

        this.wallet = this.web3.eth.accounts.wallet;
        this.account = this.web3.eth.accountProvider.privateKeyToAccount(this.secret);
        this.wallet.add(this.account);
    }

    async connectContract() {
        this.abi = JSON.parse(await fs.readFile("contracts/Contract.abi", "utf-8"));
        this.address = await fs.readFile("contracts/Contract.address");
        this.contract = new this.web3.eth.Contract(this.abi, this.contract_address);
        return this.contract;
    }

}

export { Entity }