import { Web3 } from 'web3';
import { promises as fs } from 'fs';

class Entity {

    /*
     * Variables
     */

    secret;
    network;
    web3;

    wallet;
    account;

    contract;

    abi;
    contract_address;

    /**
     * Functions
     */

    constructor(secret, network) {
        this.secret = secret;
        this.network = network;

        this.web3 = new Web3(this.network);
        this.web3.defaultNetworkId = 15;

        this.wallet = this.web3.eth.accounts.wallet;
        this.account = this.web3.eth.accountProvider.privateKeyToAccount(this.secret);
        this.wallet.add(this.account);
        this.web3.eth.defaultAccount = this.account.address;
    }

    async connectContract() {
        this.abi = JSON.parse(await fs.readFile("contracts/Contract.abi", "utf-8"));
        this.contract_address = await fs.readFile("contracts/Contract.address", "utf-8");
        this.contract = await new this.web3.eth.Contract(this.abi, this.contract_address);
        this.contract.defaultAccount = this.account.address;
        this.contract.defaultNetworkId = 15;
        return this.contract;
    }

    async isRegistered(address = this.account.address) {
        return await this.contract.methods.isRegistered(address).call();
    }
    async isCPO(address = this.account.address) {
        return await this.contract.methods.isCPO(address).call();
    }
    async isCS(address = this.account.address) {
        return await this.contract.methods.isCS(address).call();
    }
    async isEV(address = this.account.address) {
        return await this.contract.methods.isEV(address).call();
    }

    async balance(address = this.account.address) {
        return await this.web3.eth.getBalance(address);
    }

}

export { Entity }