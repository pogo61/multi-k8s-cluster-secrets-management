#!/usr/bin/env node
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const ConfigFactory_1 = require("./ConfigFactory");
let vaultVars = new Map();
vaultVars.set("/secret/google/api|token", "token");
try {
    let config = new ConfigFactory_1.ConfigFactory();
    const confVars = Promise.all([config.createVars(vaultVars)]);
    confVars.then((result) => {
        for (let key of result[0].keys()) {
            console.log("key is: " + key + " value is: " + result[0].get(key));
        }
    });
}
catch (err) {
    console.log("call to the config factory rejected: ", err);
}
//# sourceMappingURL=VaultTest.js.map