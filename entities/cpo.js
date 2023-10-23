import { Entity } from './entity.js';

class CPO extends Entity {

    constructor() {
        super(
            '0x7efa5e9cc6abc293f1f11072ea93c57c2ae5ecc4dc358ef77d9d2c6c9d9b6ab7', // secret
            'ws://192.168.174.129:8546' // network
        )
        
    }

}

export { CPO }