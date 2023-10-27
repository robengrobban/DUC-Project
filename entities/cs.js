import { Entity } from './entity.js';

class CS extends Entity {

    /**
     * Variables
     */

    type = 2;
    powerDischarge = 22000; // Watt output

    /**
     * Functions
     */
    
    constructor() {
        // address = 0x2C2C18Fe7E216447231198E039d2997615620eD7
        super(
            '0x59fe2715b3dae7ea659aa4d4466d1dbeda7f1d7835fbace6c0da14c303018d30', // secret
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

}

export { CS }