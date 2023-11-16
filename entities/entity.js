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

    /**
     * Functions
     */

    constructor(secret, network) {
        this.secret = secret;
        this.network = network;

        this.web3 = new Web3(this.network);

        this.wallet = this.web3.eth.accounts.wallet;
        this.account = this.web3.eth.accountProvider.privateKeyToAccount(this.secret);
        this.wallet.add(this.account);
        this.web3.eth.defaultAccount = this.account.address;
    }

    getTime() {
        return Math.floor(Date.now() / 1000);
    }

    listen(event, filter = {}) {
        return this.contract.events[event]({
            fromBlock: 'latest',
            filter: filter
        });
    }

    async connectContract() {
        let abi = JSON.parse(await fs.readFile("contracts/abi/Contract.abi", "utf-8"));
        let contract_address = await fs.readFile("contracts/address/Contract.address", "utf-8");

        this.contract = new this.web3.eth.Contract(abi, contract_address);
        this.contract.defaultAccount = this.account.address;

        return this.contract;
    }

    async isRegistered(address = this.account.address) {
        return await this.contract.methods.isRegistered(
            address
        ).call();
    }
    async isCPO(address = this.account.address) {
        return await this.contract.methods.isCPO(
            address
        ).call();
    }
    async isCS(address = this.account.address) {
        return await this.contract.methods.isCS(
            address
        ).call();
    }
    async isEV(address = this.account.address) {
        return await this.contract.methods.isEV(
            address
        ).call();
    }

    async balance(address = this.account.address) {
        return await this.web3.eth.getBalance(
            address
        );
    }

    async debugOwner() {
        return await this.contract.methods.debugOwner().call();
    }
    async debugDeal(EVaddress, CPOaddress) {
        return await this.contract.methods.debugDeal(
            EVaddress, 
            CPOaddress
        ).call();
    }
    async debugConnection(EVaddress, CSaddress) {
        return await this.contract.methods.debugConnection(
            EVaddress, 
            CSaddress
        ).call();
    }
    async debugChargingScheme(EVaddress, CSaddress) {
        return await this.contract.methods.debugChargingScheme(
            EVaddress, 
            CSaddress
        ).call();
    }
    async debugEV(address = this.account.address) {
        return await this.contract.methods.debugEV(
            address
        ).call();
    }
    async debugCS(address = this.account.address) {
        return await this.contract.methods.debugCS(
            address
        ).call();
    }
    async debugCPO(address = this.account.address) {
        return await this.contract.methods.debugCPO(
            address
        ).call();
    }

}

export { Entity }