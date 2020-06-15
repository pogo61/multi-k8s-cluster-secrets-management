#!/usr/bin/env node

import {ConfigFactory} from "./ConfigFactory";

    let vaultVars = new Map();
    vaultVars.set("secret/exampleapp/config|token","token");

    try {
        let config = new ConfigFactory();
        const confVars: Promise<Map<string, string>[]> = Promise.all([config.createVars(vaultVars)]);
        confVars.then((result) => {
            for (let key of result[0].keys()) {
                console.log("key is: "+ key +" value is: " + result[0].get(key));
            }
        });
    }
    catch (err) {
        console.log("call to the config factory rejected: ", err);
    }

