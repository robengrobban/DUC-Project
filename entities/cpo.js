import { Entity } from './entity.js';

class CPO extends Entity {

    /**
     * Variables
     */

    name = "VTNFL"
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
            this.account.address,
            this.web3.utils.fromAscii(this.name)
        ).send();
    }

    async registerCS(CSaddress, powerDischarge) {
        return await this.contract.methods.registerCS(
            this.account.address, 
            CSaddress, 
            this.web3.utils.fromAscii("SE1"),
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

    async registerNewRates(rates, roaming) {
        return await this.contract.methods.setRates(
            this.account.address, 
            this.web3.utils.fromAscii("SE1"),
            rates,
            roaming, 
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
            //rates[i] = this.web3.utils.toBigInt(Math.floor( (this.pricePerWattHoursToWattSeconds(0.0005)*this.ratePrecision)+0.5 ));
        }
        return rates;
    }

    generateRoaming() {
        return this.web3.utils.toBigInt(Math.floor( (this.pricePerWattHoursToWattSeconds(0.0001)*this.ratePrecision)+0.5 ));
    }

    pricePerWattHoursToWattSeconds(price) {
        return price / 3600
    }

}

export { CPO }