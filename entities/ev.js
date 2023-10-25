import { Entity } from './entity.js';

class EV extends Entity {

    /**
     * Variables
     */

    model = 'Volvo C40'
    currentCapacity = 39000;
    maxCapacity = 78000;
    batteryEfficiency = 0.9;

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
        return await this.contract.methods.registerEV(this.account.address, this.maxCapacity, (this.batteryEfficiency*100)).send();
    }

    async proposeDeal(CPOaddress) {
        return await this.contract.methods.proposeDeal(this.account.address, CPOaddress).send();
    }

    async connect(CSaddress, nonce) {
        return await this.contract.methods.connect(this.account.address, CSaddress, this.web3.utils.toBigInt(nonce)).send();
    }

}

export { EV }