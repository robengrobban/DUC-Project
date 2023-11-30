import { EV } from '../entities/ev.js';
import { CS } from '../entities/cs.js';
import { CPO } from '../entities/cpo.js';

const car = new EV('0xd0a5e7b124eb5c1d327f7c19c988bb57979637043e52db48683da62900973b96');
const station = new CS('0x59fe2715b3dae7ea659aa4d4466d1dbeda7f1d7835fbace6c0da14c303018d30');
const operator = new CPO('0x7efa5e9cc6abc293f1f11072ea93c57c2ae5ecc4dc358ef77d9d2c6c9d9b6ab7');
const operator2 = new CPO('0x59ee2d860463134cb23261befed94eec33516334781a2725ded2ff1265da51d4');

await car.connectContract();
await station.connectContract();
await operator.connectContract();
await operator2.connectContract();

car.listen('Payment').on('data', log => {
    console.log("Payment: ", log.returnValues);
});

if (false) {
    console.log("DEBUG EV: ", await car.getEV());
    console.log("DEBUG CPO: ", await operator.getCPO());
    console.log("DEBUG CS: ", await station.getCS());
    console.log("DEBUG DEAL: ", await car.getDeal(car.account.address, operator.account.address));
    console.log("DEBUG CONNECTION: ", await car.getConnection(car.account.address, station.account.address));
    console.log("DEBUG CHARGING SCHEME: ", await car.getCharging(car.account.address, station.account.address));
    console.log("DEBUG RATING: ", await operator.getRate(operator.account.address, "SE1"));
    console.log("EV MONEY: ", await car.balance());
    console.log("EV DEPOSIT: ", await car.getDeposit());
    console.log("CPO MONEY: ", await operator.balance());
}

if (false) {
    // Register entities
    operator.listen('CPORegistered').on('data', log => {
        console.log("Newly registered CPO: ", log.returnValues);
    });
    station.listen('CSRegistered').on('data', log => {
        console.log("Newly registered CS: ", log.returnValues);
    });
    car.listen('EVRegistered').on('data', log => {
        console.log("Newly registered EV: ", log.returnValues);
    });

    console.log("Registring EV...");
    await car.register();
    console.log("Registring CPO 1...");
    await operator.register(false);
    console.log("Registring CPO 2...");
    await operator2.register(false);
    console.log("Registring CS...");
    await operator.registerCS(station.account.address, station.powerDischarge);

    console.log("EV status: " + await car.isRegistered() + " " + await car.isEV());
    console.log("CPO status: " + await operator.isRegistered() + " " + await operator.isCPO());
    console.log("CS status: " + await station.isRegistered() + " " + await station.isCS());

    // Register rates
    operator.listen('NewRates').on('data', log => {
        console.log("New rates: ", log.returnValues);
    });

    console.log("Registring new rates...");
    let rates = operator.generateRates();
    let roaming = operator.generateRoaming();
    await operator.registerNewRates(rates, roaming);

    // Propose deal
    operator.listen('DealProposed').on('data', async log => {
        console.log("New deal arrived: ", log.returnValues);
        console.log("ev: ", log.returnValues.ev);
        console.log("id: ", log.returnValues.deal.id);
        console.log("Answering deal...");
        await operator.respondDeal(log.returnValues.ev, true, log.returnValues.deal.id);
    });
    car.listen('DealResponded').on('data', log => {
        console.log("Response to deal: ", log.returnValues);
        console.log("Accepted? ", log.returnValues.deal.accepted);
    });

    console.log("Proposing deal...");
    await car.proposeDeal(operator.account.address);

    // Make connection
    station.listen('ConnectionMade').on('data', log => {
        console.log("CS got connection event: ", log.returnValues);
    });
    car.listen('ConnectionMade').on('data', log => {
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
    station.listen('Disconnection').on('data', log => {
        console.log("CS disconnection event: ", log.returnValues);
    });
    car.listen('Disconnection').on('data', log => {
        console.log("EV disconnection event: ", log.returnValues);
    });

    console.log("EV disconnecting from CS...");
    await car.disconnect(station.account.address);
}
if (false) {
    // Register rates
    operator.listen('NewRates').on('data', log => {
        console.log("New rates: ", log.returnValues);
    });

    console.log("Registring new rates...");
    let rates = operator.generateRates();
    let roaming = operator.generateRoaming();
    await operator.registerNewRates(rates, roaming);
}
if (false) {
    operator.listen('NewRates').on('data', log => {
        console.log("New rates: ", log.returnValues);
    });
    console.log("Next roaming");
    await operator.registerNextRoaming(operator.generateRoaming());
}
if (false) {
    console.log("Prompring for new rates");
    console.log(await car.contract.methods.updateAutomaticRates().send());
}
if (false) {
    // Calculate charging price
    //console.log(await car.estimateChargingPrice(station.account.address));
    console.log(await car.getChargingScheme(station.account.address, operator2.account.address));
}
if (false) {
    // Listenings
    car.listen('ChargingAcknowledged').on('data', async log => {
        console.log("EV got start charging event ", log.returnValues);
    });
    station.listen('ChargingAcknowledged').on('data', log => {
        console.log("CS got start charging event ", log.returnValues);
    });
    station.listen('ChargingRequested').on('data', async log => {
        console.log("CS charging request ", log.returnValues);
        // Start charging
        if (false) {
            let schemeId = log.returnValues.scheme.id;
            let EVaddress = log.returnValues.ev;
            console.log("CS is responding to charging request ", schemeId);
            await station.acknowledgeCharging(EVaddress, schemeId);
        }
    });

    // Request charging
    console.log("EV requests charging...");
    await car.requestCharging(1000, station.account.address, operator.account.address, car.getTime() + 30);
}
if (false) {
    // Listenings
    car.listen('ChargingStopped').on('data', log => {
        console.log("EV got stop charging event ", log.returnValues);
    });
    station.listen('ChargingStopped').on('data', log => {
        console.log("CS got stop charging event ", log.returnValues);
    });

    // Stop charging
    console.log("EV stops charging...");
    console.log(car.getTime());
    await car.stopCharging(station.account.address);
}
if (false) {
    car.listen("SmartChargingScheduled").on('data', async log => {
        console.log("EV new smart charging schedule...", log.returnValues);
        // Accept
        if (true) {
            console.log("EV accept smart charging schedule... ", log.returnValues.scheme.id);
            let schemeId = log.returnValues.scheme.id;
            let CSaddress = log.returnValues.cs;
            await car.acceptSmartCharging(1000, CSaddress, schemeId);
        }
    });

    if (true) {
        car.listen('ChargingAcknowledged').on('data', log => {
            console.log("EV got start charging event ", log.returnValues);
        });
        station.listen('ChargingAcknowledged').on('data', log => {
            console.log("CS got start charging event ", log.returnValues);
        });
        station.listen('ChargingRequested').on('data', async log => {
            // Start charging
            console.log("CS charging request ", log.returnValues);
            let schemeId = log.returnValues.scheme.id;
            let EVaddress = log.returnValues.ev;
            console.log("CS is responding to charging request ", schemeId);
            await station.acknowledgeCharging(EVaddress, schemeId);
        });
    }
    console.log("Scheduling smart charging...");
    car.scheduleSmartCharging(station.account.address, operator.account.address);
}