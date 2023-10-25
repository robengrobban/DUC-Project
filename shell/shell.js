import { EV } from '../entities/ev.js';
import { CS } from '../entities/cs.js';
import { CPO } from '../entities/cpo.js';

const car = new EV();
const station = new CS();
const operator = new CPO();

await car.connectContract();
await station.connectContract();
await operator.connectContract();

if ( true ) {
    operator.contract.events.RegisteredCPO({fromBlock: 'latest'}).on('data', log => {
        console.log("Newly registered CPO: ", log);
    });
    station.contract.events.RegisteredCS({fromBlock: 'latest'}).on('data', log => {
        console.log("Newly registered CS: ", log);
    });
    car.contract.events.RegisteredEV({fromBlock: 'latest'}).on('data', log => {
        console.log("Newly registered EV: ", log);
    })
}

if ( true ) {
    console.log("Registring EV...");
    await car.register();
    console.log("Registring CPO...");
    await operator.register();
    console.log("Registring CS...");
    await operator.registerCS(station.account.address, station.powerDischarge);
}

if ( true ) {
    console.log("EV status: " + await car.isRegistered() + " " + await car.isEV());
    console.log("CPO status: " + await operator.isRegistered() + " " + await operator.isCPO());
    console.log("CS status: " + await station.isRegistered() + " " + await station.isCS());

    console.log("DEBUG EV: ", await car.debugEV());
    console.log("DEBUG CPO: ", await operator.debugCPO());
    console.log("DEBUG CS: ", await station.debugCS());
}

if ( true ) {
    operator.contract.events.NewRates({fromBlock: 'latest'}).on('data', log => {
        console.log("New reates: ", log);
    });

    // Register rates
    console.log("Registring new rates...");
    let rates = operator.generateRates();
    await operator.registerNewRates(rates);

}

if ( true ) {
    operator.contract.events.ProposedDeal({fromBlock: 'latest'}).on('data', log => {
        console.log("New deal arrived: ", log);
        console.log("ev: ", log.returnValues.ev);
        console.log("id: ", log.returnValues.deal.id);
        console.log("Answering deal...");
        operator.respondDeal(log.returnValues.ev, true, log.returnValues.deal.id);
    });
    car.contract.events.RespondDeal({fromBlock: 'latest'}).on('data', log => {
        console.log("Response to deal: ", log);
        console.log("Accepted? ", log.returnValues.deal.accepted);
    });

    console.log("Proposing deal...");
    await car.proposeDeal(operator.account.address);

    console.log("DEBUG DEAL: ", await car.debugDeal(car.account.address, operator.account.address));

}

if ( true ) {
    station.contract.events.ConnectionMade({fromBlock: 'latest'}).on('data', log => {
        console.log("CS got connection event: ", log);
    });
    car.contract.events.ConnectionMade({fromBlock: 'latest'}).on('data', log => {
        console.log("EV got connection event: ", log);
    });

    let nonce = station.generateNonce();
    console.log("EV connects to CS and gets NONCE: ", nonce);
    console.log("CS sends connection...");
    await station.connect(car.account.address, nonce);
    console.log("EV sends connection...");
    await car.connect(station.account.address, nonce);

    console.log("DEBUG CONNECTION: ", await car.debugConnection(car.account.address, station.account.address));

}

