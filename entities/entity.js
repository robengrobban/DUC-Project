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

    precision = 1000000000;

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

    async getDeal(EVaddress, CPOaddress) {
        return await this.contract.methods.getDeal(
            EVaddress, 
            CPOaddress
        ).call();
    }
    async getConnection(EVaddress, CSaddress) {
        return await this.contract.methods.getConnection(
            EVaddress, 
            CSaddress
        ).call();
    }
    async getCharging(EVaddress, CSaddress) {
        return await this.contract.methods.getCharging(
            EVaddress, 
            CSaddress
        ).call();
    }
    async getEV(address = this.account.address) {
        return await this.contract.methods.getEV(
            address
        ).call();
    }
    async getCS(address = this.account.address) {
        return await this.contract.methods.getCS(
            address
        ).call();
    }
    async getCPO(address = this.account.address) {
        return await this.contract.methods.getCPO(
            address
        ).call();
    }
    async getRate(address, region) {
        return await this.contract.methods.getRate(
            address,
            this.web3.utils.fromAscii(region)
        ).call();
    }

}

export { Entity }