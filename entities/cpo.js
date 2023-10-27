import { Entity } from './entity.js';

class CPO extends Entity {

    /**
     * Variables
     */

    rateSlots = 60;
    ratePrecision = 1000000000;

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
        return await this.contract.methods.registerCPO(
            this.account.address
        ).send();
    }

    async registerCS(CSaddress, powerDischarge) {
        return await this.contract.methods.registerCS(
            this.account.address, 
            CSaddress, 
            powerDischarge
        ).send();
    }

    async respondDeal(EVaddress, answer, id) {
        return await this.contract.methods.respondDeal(
            this.account.address, 
            EVaddress, 
            answer, 
            id
        ).send();
    }

    async registerNewRates(rates) {
        return await this.contract.methods.setRates(
            this.account.address, 
            rates, 
            this.ratePrecision
        ).send();
    }

    generateRates() {
        let rates = [];
        for (let i = 0; i < this.rateSlots; i++) {
            //rates[i] = this.web3.utils.toBigInt( Math.floor(this.pricePerWattHoursToWattSeconds((-0.1*i**2 + 6*i + 5)*this.ratePrecision)) );
            rates[i] = this.web3.utils.toBigInt(Math.floor( (this.pricePerWattHoursToWattSeconds(0.001)*this.ratePrecision)+0.5 ));
        }
        return rates;
    }

    pricePerWattHoursToWattSeconds(price) {
        return price / 3600
    }

}

export { CPO }