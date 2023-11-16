// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

uint constant RATE_SLOTS = 60;                  // How many rate slots there are, should be compatible with how often the rate changes.

uint constant RATE_CHANGE_IN_SECONDS = 3600;    // What is the factor of rate changes in seconds? 
                                                // Used to calculate when a new rate starts, see function getNextRateChange()
                                                // 60 = rate change every minute
                                                // 3600 = rate change every hour (60 * 60)
                                                // 86400 = rate change every day (60 * 60 * 24)

uint constant RATE_SLOT_PERIOD = RATE_CHANGE_IN_SECONDS / RATE_SLOTS;   // This gives how many seconds are in one rate slot period
                                                                        // If rate changes every hour, and have a new price every minute
                                                                        // That means that there are 60 seconds to account for in each 
                                                                        // rate charging period.
                                                                        // If hourly rate are user -> 86400 / 24 = 3600, there are so many seconds
                                                                        // in one hour, which is one charging period.
                                                                        // This is important as prices are related to this, so RATE_CHARGE_PERIOD
                                                                        // are the amount of seconds that needs to pass in order for the full charge
                                                                        // rate price to be accounted for. 

uint constant WEI_FACTOR = 100;     // This says that the price to pay is per 100 WEI. Meaning, if the price gets calculated to 4.3, it would mean
                                    // that 430 WEI is the price. Higher value will grant higher precision, but this works fine for testing.

uint constant PRECISION = 1000000000;           // Affects the precision on calculation, as they are all integer calulcations.

interface Structure {
    
    struct PrecisionNumber {
        uint value;
        uint precision;
    }

    struct CPO {
        bool exist;
        bytes5 name;
        address _address;
        bool useNordPoolRates;
    }
    struct CS {
        bool exist;
        address _address;
        bytes3 region;
        uint powerDischarge; // Watt output
        address cpo; // Connection to what CPO
    }
    struct EV {
        bool exist;
        address _address;
        uint maxCapacity; // Watt Seconds of max charge
        uint batteryEfficiency; // Battery charge efficency (0-100)
    }

    struct Deal {
        uint id;
        bool accepted;
        address EV;
        address CPO;
        uint startDate;
        uint endDate;
        bool onlyRewneableEnergy;
        PrecisionNumber maxRate;
        bool allowSmartCharging;
    }

    struct Connection {
        uint nonce;
        address EV;
        address CS;
        bool EVconnected;
        bool CSconnected;
        uint establishedDate;
    }

    struct Rate {
        bytes3 region;

        uint[RATE_SLOTS] current; // Rate in Watt seconds
        uint startDate; // The date when the rates was applied
        uint precision; // The selected precision for Rates. (INT calculation)

        uint[RATE_SLOTS] next; // The next scheduled rates
        uint changeDate; // The date when the new rates are expected to change

        uint[RATE_SLOTS] historical; // What the last rate was
        uint historicalDate; // When the rates in historical started
    }

    struct ChargingScheme {
        uint id;
        bool EVaccepted;
        bool CSaccepted;
        bool finished;
        bool smartCharging;
        uint targetCharge; // Watt seconds of target charge
        uint outputCharge; // Watt seconds of output charge, if full scheme is used
        uint startCharge; // Watt seconds of start charge
        uint startTime; // Unix time for when charging starts
        uint chargeTime; // Seconds of time CS is charging EV
        uint idleTime; // Seconds of time CS is not charging EV, based on user preferences of max rates
        uint maxTime; // The maximum amount of time a scheme can run for (ends at deal end or when new (unkown) rates start)
        uint endTime; // Unix time for when charging should end
        uint finishTime; // Unix time for when charing actually end
        bytes3 region;
        PrecisionNumber price;
        uint priceInWei;
        PrecisionNumber finalPrice;
        uint finalPriceInWei;
        uint slotsUsed;
        uint[RATE_SLOTS*2] durations;
        uint[RATE_SLOTS*2] prices;
    }

    struct Triplett {
        EV ev;
        CS cs;
        CPO cpo;
    }

}