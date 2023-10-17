import { Entity } from './entity.js'

class EV extends Entity {

    constructor() {
        super(
            '0x5DAff3F5C181fE4692CAD290d729D8478ee34E1D', // address
            '0xd0a5e7b124eb5c1d327f7c19c988bb57979637043e52db48683da62900973b96', // secret
            'ws://192.168.174.130:8546' // network
        )
        
    }

    async balance() {
        console.log("Start transaction")
        let balance = await this.web3.eth.getBalance(this.address)
        console.log("End transaction")
        return balance;
    }

}

export { EV }