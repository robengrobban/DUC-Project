import { EV } from '../entities/ev.js';
import { CS } from '../entities/cs.js';
import { CPO } from '../entities/cpo.js';

const car = new EV();
const station = new CS();
const operator = new CPO();

console.log(await car.balance());

await car.connectContract();
let result = await car.register();
console.log(result);

//console.log(car)