import { Entity } from './entity.js';

class EV extends Entity {

    constructor() {
        super(
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

        let response = await this.contract.methods.registerEV(this.address).send();
        return response;
    }

    async sendMoney() {
        let tx = {
            to: '0x2C2C18Fe7E216447231198E039d2997615620eD7',
            value: 100
        }

        return await this.web3.eth.sendTransaction(tx);
    }

}

export { EV }