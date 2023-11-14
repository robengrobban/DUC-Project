import { Entity } from './entity.js';

class CS extends Entity {

    /**
     * Variables
     */

    type = 2;
    powerDischarge = 22000; // Watt output
    region = "SE1";

    /**
     * Functions
     */
    
    constructor(secret) {
        super(
            secret, // secret
            'ws://192.168.174.131:8546' // network
        )
        
    }

    generateNonce() {
        let min = Math.ceil(1);
        let max = Math.floor(1000000000000000000);
        return Math.floor(Math.random() *  (max - min + 1) + min)
    }

    async connect(EVaddress, nonce) {
        return await this.contract.methods.connect(
            EVaddress, 
            this.account.address,
            this.web3.utils.toBigInt(nonce)
        ).send();
    }

    async acknowledgeCharging(EVaddress, schemeId) {
        return await this.contract.methods.acknowledgeCharging(
            this.account.address,
            EVaddress,
            schemeId
        ).send();
    }

    async stopCharging(EVaddress) {
        return await this.contract.methods.stopCharging(
            EVaddress,
            this.account.address
        ).send();
    }

}

export { CS }