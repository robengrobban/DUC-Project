import { Web3 } from 'web3'

class Entity {

    constructor(address, secret, network) {
        this.address = address
        this.secret = secret
        this.network = network
        this.web3 = new Web3(this.network)
    }

}

export { Entity }