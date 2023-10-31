import { EV } from '../entities/ev.js';
import { CS } from '../entities/cs.js';
import { CPO } from '../entities/cpo.js';

const car = new EV();
const station = new CS();
const operator = new CPO();

await car.connectContract();
await station.connectContract();
await operator.connectContract();

if (false) {
    console.log("DEBUG EV: ", await car.debugEV());
    console.log("DEBUG CPO: ", await operator.debugCPO());
    console.log("DEBUG CS: ", await station.debugCS());
    console.log("DEBUG DEAL: ", await car.debugDeal(car.account.address, operator.account.address));
    console.log("DEBUG CONNECTION: ", await car.debugConnection(car.account.address, station.account.address));
}

if (false) {
    // Register entities
    operator.contract.events.RegisteredCPO({fromBlock: 'latest'}).on('data', log => {
        console.log("Newly registered CPO: ", log.returnValues);
    });
    station.contract.events.RegisteredCS({fromBlock: 'latest'}).on('data', log => {
        console.log("Newly registered CS: ", log.returnValues);
    });
    car.contract.events.RegisteredEV({fromBlock: 'latest'}).on('data', log => {
        console.log("Newly registered EV: ", log.returnValues);
    });

    console.log("Registring EV...");
    await car.register();
    console.log("Registring CPO...");
    await operator.register();
    console.log("Registring CS...");
    await operator.registerCS(station.account.address, station.powerDischarge);

    console.log("EV status: " + await car.isRegistered() + " " + await car.isEV());
    console.log("CPO status: " + await operator.isRegistered() + " " + await operator.isCPO());
    console.log("CS status: " + await station.isRegistered() + " " + await station.isCS());

    // Register rates
    operator.contract.events.NewRates({fromBlock: 'latest'}).on('data', log => {
        console.log("New rates: ", log.returnValues);
    });

    console.log("Registring new rates...");
    let rates = operator.generateRates();
    await operator.registerNewRates(rates);

    // Propose deal
    operator.contract.events.ProposedDeal({fromBlock: 'latest'}).on('data', log => {
        console.log("New deal arrived: ", log.returnValues);
        console.log("ev: ", log.returnValues.ev);
        console.log("id: ", log.returnValues.deal.id);
        console.log("Answering deal...");
        operator.respondDeal(log.returnValues.ev, true, log.returnValues.deal.id);
    });
    car.contract.events.RespondDeal({fromBlock: 'latest'}).on('data', log => {
        console.log("Response to deal: ", log.returnValues);
        console.log("Accepted? ", log.returnValues.deal.accepted);
    });

    console.log("Proposing deal...");
    await car.proposeDeal(operator.account.address);

    // Make connection
    station.contract.events.ConnectionMade({fromBlock: 'latest'}).on('data', log => {
        console.log("CS got connection event: ", log.returnValues);
    });
    car.contract.events.ConnectionMade({fromBlock: 'latest'}).on('data', log => {
        console.log("EV got connection event: ", log.returnValues);
    });

    let nonce = station.generateNonce();
    console.log("EV connects to CS and gets NONCE: ", nonce);
    console.log("CS sends connection...");
    await station.connect(car.account.address, nonce);
    console.log("EV sends connection...");
    await car.connect(station.account.address, nonce);
}
if (false) {
    // Disconnect
    station.contract.events.Disconnection({fromBlock: 'latest'}).on('data', log => {
        console.log("CS disconnection event: ", log.returnValues);
    });
    car.contract.events.Disconnection({fromBlock: 'latest'}).on('data', log => {
        console.log("EV disconnection event: ", log.returnValues);
    });

    console.log("EV disconnecting from CS...");
    await car.disconnect(station.account.address);
}
if (false) {
    // Register rates
    operator.contract.events.NewRates({fromBlock: 'latest'}).on('data', log => {
        console.log("New rates: ", log.returnValues);
    });

    console.log("Registring new rates...");
    let rates = operator.generateRates();
    await operator.registerNewRates(rates);
}
if (false) {
    // Calculate charging price
    console.log(await car.estimateChargingPrice(station.account.address));
    console.log(await car.getChargingScheme(station.account.address));
}