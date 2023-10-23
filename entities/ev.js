import { Entity } from './entity.js';

class EV extends Entity {

    /**
     * Variables
     */

    /**
     * Functions
     */

    constructor() {
        // address = 0x5DAff3F5C181fE4692CAD290d729D8478ee34E1D
        super(
            '0xd0a5e7b124eb5c1d327f7c19c988bb57979637043e52db48683da62900973b96', // secret
            'ws://192.168.174.130:8546' // network
        )
        
    }

    async register() {
        return await this.contract.methods.registerEV(this.account.address).send();
    }

    async proposeDeal(CPOaddress) {
        return await this.contract.methods.proposeDeal(this.account.address, CPOaddress).send();
    }

}

export { EV }