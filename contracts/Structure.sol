// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

uint constant RATE_SLOTS = 60;                  // How many rate slots there are, should be compatible with how often the rate changes.

uint constant RATE_CHANGE_IN_SECONDS = 3600;    // What is the factor of rate changes in seconds? 
                                                // Used to calculate when a new rate starts, see function getNextRateChangeAtTime()
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
        address _address;
        bytes5 name;
        bool automaticRates;
    }
    struct CS {
        address _address;
        bytes3 region; // Region CS is in, affects rates/roaming
        uint powerDischarge; // Watt output
        bool hasRenewableEnergy; // If RES is available at this CS
        address cpo; // Connection to what CPO
    }
    struct EV {
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
        DealParameters parameters;
    }
    struct DealParameters {
        PrecisionNumber maxRate;
        bool onlyRewneableEnergy;
        bool allowSmartCharging;
    }

    struct Connection {
        uint nonce;
        bool EVconnected;
        bool CSconnected;
        uint establishedDate;
    }

    struct Rate {
        bytes3 region;
        uint precision; // The selected precision for Rates. (INT calculation)

        uint[RATE_SLOTS] current; // Rate per Watt seconds
        uint currentRoaming; // Roaming rate per Watt seconds
        uint startDate; // The date when the rates was applied

        uint[RATE_SLOTS] next; // The next scheduled rates
        uint nextRoaming; // The next roaming rates
        uint changeDate; // The date when the new rates are expected to change

        //uint[RATE_SLOTS] historical; // What the last rate was
        //uint historicalRoaming; // What the roaming last was
        //uint historicalDate; // When the rates in historical started

        uint automaticNextRoaming; // The next roaming when the next automatic update happens.
    }

    struct ChargingScheme {
        uint id;

        address CPOaddress; // Address of which CPO is used for rates
        bool roaming; // If this charging scheme is of type roaming, 

        bool EVaccepted;
        bool CSaccepted;

        bool finished;
        bool smartCharging; // True if the scheme originated from a smart charging request

        uint targetCharge; // Watt seconds of target charge
        uint outputCharge; // Watt seconds of output charge, if full scheme is used

        uint startCharge; // Watt seconds of start charge
        uint startDate; // Unix time for when charging starts
        uint chargeTime; // Seconds of time needed to charge EV
        uint activeTime; // Seconds of time CS is charging EV, based on user preferneces of max rates
        uint idleTime; // Seconds of time CS is not charging EV, based on user preferences of max rates
        uint maxTime; // The maximum amount of time a scheme can run for in seconds (ends at deal end or when new (unkown) rates start)
        uint endDate; // Unix time for when charging should end
        uint finishDate; // Unix time for when charing actually end
        
        bytes3 region;

        PrecisionNumber price;
        uint priceInWei;

        PrecisionNumber roamingPrice;
        uint roamingPriceInWei;

        PrecisionNumber finalPrice;
        uint finalPriceInWei;

        PrecisionNumber finalRoamingPrice;
        uint finalRoamingPriceInWei;

        uint slotsUsed;
        uint[RATE_SLOTS*2] durations;
        uint[RATE_SLOTS*2] prices;
        uint[RATE_SLOTS*2] roamingFees;
    }

    struct Triplett {
        EV ev;
        CS cs;
        CPO cpo;
    }

    struct Chargelett {
        Deal deal;
        Rate rate;
        Rate roaming;
    }

}