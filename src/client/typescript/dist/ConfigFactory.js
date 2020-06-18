"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const fs_1 = __importDefault(require("fs"));
class ConfigFactory {
    constructor() {
        this.roleName = "cf-test";
        this.baseTokenPath = "/var/run/secrets/kubernetes.io/serviceaccount/";
        this.baseLoginCheckDir = "/tmp/";
        this.LoginCheckDir = "configfactory";
        this.tokenFile = "token";
        this.tokenFilecheck = "loggedin.chk";
        this.baseLoginCheckPath = this.baseLoginCheckDir + this.LoginCheckDir;
        this.tokenPath = this.baseTokenPath + this.tokenFile;
        this.loginCheckPath = this.baseLoginCheckPath + "/" + this.tokenFilecheck;
        // console.log("in constructor")
        this.url = process.env.VAULT_ADDR;
    }
    createVars(vaultValues) {
        return __awaiter(this, void 0, void 0, function* () {
            // process.env.DEBUG = 'node-vault'; // switch on debug mode
            // this file was created when last logged in, and will exist unless token is recreated by K8s
            console.log("checking if already logged in");
            if (!fs_1.default.existsSync(this.loginCheckPath)) {
                yield this.Login();
            }
            // create map to be returned
            let newMap = new Map();
            // set up client to access vault`
            let client_options = {
                apiVersion: 'v1',
                endpoint: this.url,
                token: this.token,
                json: false
            };
            // create a vault access client
            let client_vault = require("node-vault")(client_options);
            // read the secret from Vault then get the value of the field requested and create an entry in the new Map
            // console.log("read the secret from Vault then get the value of the field requested and create an entry in the new Map");
            for (let key of vaultValues.keys()) {
                let splitKey = key.split('|');
                let temp = splitKey[0];
                let secret = temp.slice(0, 7) + "/data" + temp.slice(7);
                let field = splitKey[1];
                // console.log("the secret needed is "+secret+" and the field is "+field);
                // console.log("reading the secret from vault");
                yield client_vault.read(secret).then((body) => {
                    if (field != undefined) {
                        newMap.set(vaultValues.get(key), body.data.data[field]);
                        // console.log("vaultValues.get(key) is "+vaultValues.get(key))
                        // console.log("reading the field value from vault is "+body.data.data[field]);
                    }
                    else {
                        // console.log("no field provided to read from secret");
                        return new Error("no field provided to read from secret");
                    }
                }).catch(console.error);
            }
            //return newMap;
            return Promise.resolve(newMap);
        });
    }
    Login() {
        return __awaiter(this, void 0, void 0, function* () {
            // console.log("about to login to vault");
            yield this.getVaultIp();
            yield this.vaultLogin();
            // create file to indicate login has occurred for this instance of the token
            if (!fs_1.default.existsSync(this.loginCheckPath)) {
                // making login check directory
                // console.log("making login check directory: " + this.baseLoginCheckPath)
                let pwd = process.cwd();
                process.chdir(this.baseLoginCheckDir);
                // console.log("writing check file: " + this.tokenFilecheck + " in directory " + this.baseLoginCheckPath)
                // create file to indicate login has occurred for this instance of the token
                fs_1.default.closeSync(fs_1.default.openSync(this.tokenFilecheck, 'a'));
                process.chdir(pwd);
            }
            console.log("logged in");
        });
    }
    getVaultIp() {
        return __awaiter(this, void 0, void 0, function* () {
            try {
                // define k8s cluster client
                const k8s = require('@kubernetes/client-node');
                const kc = new k8s.KubeConfig();
                kc.loadFromCluster();
                const k8sApi = kc.makeApiClient(k8s.CoreV1Api);
                const getVaultPods = Promise.all([k8sApi.listNamespacedPod('vault', null, null, null, null, 'app=vault')]);
                yield getVaultPods.then((res) => {
                    // console.log("list of response statusCode is " + res[0].response.statusCode);
                    // console.log("list of response statusMessage is " + res[0].response.statusMessage);
                    if (res[0].response.statusCode == 200) {
                        this.IP = res[0].body.items[0].status.podIP;
                        // console.log("vault IP is " + this.IP);
                        this.url = "http://" + this.IP + ":8200";
                    }
                    else {
                        return new Error("The response statusCode is " + res[0].response.statusCode + "and the response statusMessage is " + res[0].response.statusMessage);
                    }
                });
            }
            catch (err) {
                console.log("k8sApi.listNamespacedPod rejected: ", err);
            }
        });
    }
    vaultLogin() {
        return __awaiter(this, void 0, void 0, function* () {
            // set up client to access vault`
            let client_options = {
                apiVersion: 'v1',
                endpoint: this.url
            };
            // get new instance of the client
            let vault = require("node-vault")(client_options);
            try {
                // read the K8s generated token
                let jwt = fs_1.default.readFileSync(this.tokenPath, 'utf8');
                // login using the Kubernetes Auth method
                // console.log("logging into vault using jwt created for the service account");
                const login = Promise.all([vault.kubernetesLogin({ role: this.roleName, jwt: jwt })]);
                yield login.then((result) => {
                    this.token = result[0].auth.client_token;
                    // console.log("the access token is "+this.token);
                });
            }
            catch (err) {
                console.log("vault.kubernetesLogin rejected: ", err);
            }
        });
    }
}
exports.ConfigFactory = ConfigFactory;
//# sourceMappingURL=ConfigFactory.js.map