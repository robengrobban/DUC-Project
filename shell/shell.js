import { EV } from '../entities/ev.js'
import { CS } from '../entities/cs.js'
import { CPO } from '../entities/cpo.js'

const car = new EV()

console.log("Getting balance")
let balance = await car.balance()
console.log("Balance: " + balance)

//console.log(car)