import { Entity } from './entity.js';

class CPO extends Entity {

    /**
     * Variables
     */

    name = "VTNFL"
    rateSlots = 60;

    /**
     * Functions
     */

    constructor(secret) {
        super(
            secret, // secret
            'ws://192.168.174.129:8546' // network
        )
    }

    async register(automaticRates) {
        return await this.contract.methods.registerCPO(
            this.account.address,
            this.web3.utils.fromAscii(this.name),
            automaticRates
        ).send();
    }

    async registerCS(CSaddress, powerDischarge, hasRenewableEnergy) {
        return await this.contract.methods.registerCS( 
            CSaddress,
            this.account.address,
            this.web3.utils.fromAscii("SE1"),
            powerDischarge,
            hasRenewableEnergy
        ).send();
    }

    async respondDeal(EVaddress, answer, id) {
        return await this.contract.methods.respondDeal(
            EVaddress, 
            this.account.address, 
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
            this.precision
        ).send();
    }

    async registerNextRoaming(roaming) {
        return await this.contract.methods.nextRoaming(
            this.account.address, 
            this.web3.utils.fromAscii("SE1"),
            roaming, 
            this.precision
        ).send();
    }


    generateRates() {
        let rates = [];
        for (let i = 0; i < this.rateSlots; i++) {
            //rates[i] = this.web3.utils.toBigInt( Math.floor(this.pricePerWattHoursToWattSeconds((-0.1*i**2 + 6*i + 5)*this.precision)) );
            if ( i % 2 == 0 ) {
                rates[i] = this.web3.utils.toBigInt(Math.floor( (this.pricePerWattHoursToWattSeconds(0.001)*this.precision)+0.5 ));
            }
            else {
                rates[i] = this.web3.utils.toBigInt(Math.floor( (this.pricePerWattHoursToWattSeconds(0.002)*this.precision)+0.5 ));
            }
            //rates[i] = this.web3.utils.toBigInt(Math.floor( (this.pricePerWattHoursToWattSeconds(0.0005)*this.precision)+0.5 ));
        }
        return rates;
    }

    generateRoaming() {
        return this.web3.utils.toBigInt(Math.floor( (this.pricePerWattHoursToWattSeconds(0.0001)*this.precision)+0.5 ));
    }

    pricePerWattHoursToWattSeconds(price) {
        return price / 3600
    }

}

export { CPO }