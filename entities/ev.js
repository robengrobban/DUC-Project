import { Entity } from './entity.js'

class EV extends Entity {

    constructor() {
        super(
            '0x5DAff3F5C181fE4692CAD290d729D8478ee34E1D', // address
            '0xd0a5e7b124eb5c1d327f7c19c988bb57979637043e52db48683da62900973b96', // secret
            'ws://192.168.174.130:8546' // network
        )
        
    }

    async register() {
        let registered = await this.isRegistered(this.address);
        console.log(registered);
        if ( registered ) {
            throw new Error("Already registered");
        }

        let response = await this.contract.methods.registerEV(this.address).send({from: this.address});
        return response;
    }

}

export { EV }