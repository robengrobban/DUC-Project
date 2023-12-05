class RateApi {

    base_address = 'https://www.elprisetjustnu.se/api/v1/prices/';
    date = new Date();

    regionPart;

    moveDay(days = 0) {
        this.date.setDate(this.date.getDate()+days);
        return this;
    }

    setRegion(region) {
        this.regionPart = region.toUpperCase();
        return this;
    }

    build() {
        let uri = this.base_address;
        let year = this.date.getFullYear();
        let month = this.date.getMonth()+1;
        let day = this.date.getDate();
        let region = this.regionPart;

        if (month < 10) {
            month = "0"+month;
        } 
        if (day < 10) {
            day = "0"+day;
        }
        return uri + year + "/" + month + "-" + day + "_" + region + ".json";
    }

    async execute() {
        const uri = this.build();

        const response = await fetch(uri, {method: "GET"});

        if (response.ok) {
            return {
                ok: true,
                json: await response.json()
            };
        }
        else {
            return {
                ok: false,
                json: {}
            }
        }
    }

    async rates(price_adjuster = (price) => {return price}, size = 24) {

        const req = await this.execute();

        const rates = [];

        if ( req.ok ) {

            const json = req.json;

            for ( let i = 0; i < size; i++ ) {
                let index = i % json.length;
                rates[i] = price_adjuster(json[index].SEK_per_kWh);
            }

            return rates;

        }
        else {
            for ( let i = 0; i < size; i++ ) {
                rates[i] = price_adjuster(0);
            }
            return rates;
        }

    }

}

export { RateApi }