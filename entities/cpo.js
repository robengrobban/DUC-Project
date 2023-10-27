import { Entity } from './entity.js';

class CPO extends Entity {

    /**
     * Variables
     */

    rateSlots = 60;

    /**
     * Functions
     */

    constructor() {
        // address = 0x6388ECbB1e5A73B7c25747227613c1c1fE6C2D53
        super(
            '0x7efa5e9cc6abc293f1f11072ea93c57c2ae5ecc4dc358ef77d9d2c6c9d9b6ab7', // secret
            'ws://192.168.174.129:8546' // network
        )
        
    }

    async register() {
        return await this.contract.methods.registerCPO(this.account.address).send();
    }

    async registerCS(CSaddress, powerDischarge) {
        return await this.contract.methods.registerCS(this.account.address, CSaddress, powerDischarge).send();
    }

    async respondDeal(EVaddress, answer, id) {
        return await this.contract.methods.respondDeal(this.account.address, EVaddress, answer, id).send();
    }

    generateRates() {
        let rates = [];
        for (let i = 0; i < this.rateSlots; i++) {
            let precision = 1000000000;
            let rate = this.web3.utils.toBigInt( Math.floor(this.priceKiloWattHoursToWattSeconds((-0.05*i**2 + 3*i + 5)*precision)) );
            rates[i] = {value: rate, precision: precision};
        }
        return rates;
    }

    priceKiloWattHoursToWattSeconds(rate) {
        return rate / (1000 * 3600)
    }

    async registerNewRates(rates) {
        return await this.contract.methods.setRates(this.account.address, rates).send();
    }

}

export { CPO }