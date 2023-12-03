import { Web3 } from 'web3';
import { promises as fs } from 'fs';
const network = "ws://192.168.174.129:8546";

const web3 = new Web3(network);
const account = web3.eth.accountProvider.privateKeyToAccount('0x2034354a9303f3d1e14e0c838c2175daecb3cc0b9a266d5adfb0eba7ddda49c0'); // ORACLE
web3.eth.defaultAccount = account.address;
web3.wallet.add(account);

const abi = JSON.parse(await fs.readFile("contracts/abi/Oracle.abi", "utf-8"));
const contract_address = await fs.readFile("contracts/address/Oracle.address", "utf-8");

const contract = new web3.eth.Contract(abi, contract_address);
contract.defaultAccount = account.address;

console.log(await contract.methods.getOracleState(web3.utils.fromAscii("SE1")).call());

contract.events.RateRequest({
    fromBlock: 'latest'
}).on('data', async log => {

    console.log("New rate request...");

    const region = ["SE1", "SE2", "SE3", "SE4"];

    for ( let i = 0; i < region.length; i++ ) {
        console.log("Sending rates for", region[i], "...");
        await contract.methods.setRates(getTime(), web3.utils.fromAscii(region[i]), generateRates(), generateRates2()).send();
    }

    console.log("All new rates done...");

});

function generateRates() {
    let rates = [];
    for (let i = 0; i < 60; i++) {
        if ( i % 2 == 0 ) {
            rates[i] = web3.utils.toBigInt(Math.floor( (pricePerWattHoursToWattSeconds(0.001)*1000000000)+0.5 ));
        }
        else {
            rates[i] = web3.utils.toBigInt(Math.floor( (pricePerWattHoursToWattSeconds(0.002)*1000000000)+0.5 ));
        }
    }
    return rates;
}
function generateRates2() {
    let rates = [];
    for (let i = 0; i < 60; i++) {
        if ( i % 2 == 0 ) {
            rates[i] = web3.utils.toBigInt(Math.floor( (pricePerWattHoursToWattSeconds(0.003)*1000000000)+0.5 ));
        }
        else {
            rates[i] = web3.utils.toBigInt(Math.floor( (pricePerWattHoursToWattSeconds(0.004)*1000000000)+0.5 ));
        }
    }
    return rates;
}
function generateEmptyRates() {
    let rates = [];
    for (let i = 0; i < 60; i++) {
        rates[i] = web3.utils.toBigInt(0);
    }
    return rates;
}
function pricePerWattHoursToWattSeconds(price) {
    return price / 3600
}
function getTime() {
    return Math.floor(Date.now() / 1000);
}