import { Entity } from './entity.js'

class CS extends Entity {

    constructor() {
        super(
            '0x2C2C18Fe7E216447231198E039d2997615620eD7', // address
            '0x59fe2715b3dae7ea659aa4d4466d1dbeda7f1d7835fbace6c0da14c303018d30', // secret
            'ws://192.168.174.131:8546' // network
        )
        
    }

}

export { CS }