import { Entity } from './entity.js';

class CPO extends Entity {

    /**
     * Variables
     */

    name = "Vattenfall"
    rateSlots = 60;
    ratePrecision = 1000000000;

    /**
     * Functions
     */

    constructor(secret) {
        super(
            secret, // secret
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
            if ( i % 2 == 0 ) {
                rates[i] = this.web3.utils.toBigInt(Math.floor( (this.pricePerWattHoursToWattSeconds(0.001)*this.ratePrecision)+0.5 ));
            }
            else {
                rates[i] = this.web3.utils.toBigInt(Math.floor( (this.pricePerWattHoursToWattSeconds(0.002)*this.ratePrecision)+0.5 ));
            }
        }
        return rates;
    }

    pricePerWattHoursToWattSeconds(price) {
        return price / 3600
    }

}

export { CPO }