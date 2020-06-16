import fs from 'fs';
import { Base64 } from 'js-base64';
import {Cluster} from "@kubernetes/client-node/dist/config_types";

export class ConfigFactory {
    url: string;
    beam: string;
    token: string;
    IP: string;
    roleName = "cf-test";
    baseTokenPath = "/var/run/secrets/kubernetes.io/serviceaccount/";
    baseLoginCheckDir = "/tmp/";
    LoginCheckDir = "configfactory";
    tokenFile = "token";
    tokenFilecheck = "loggedin.chk";
    baseLoginCheckPath = this.baseLoginCheckDir + this.LoginCheckDir;
    tokenPath = this.baseTokenPath + this.tokenFile;
    loginCheckPath = this.baseLoginCheckPath + "/" + this.tokenFilecheck;

    constructor() {
        // console.log("in constructor")
        this.url = process.env.VAULT_URL;
        this.beam = process.env.BEAM_ENV;
    }

    async createVars(vaultValues:Map<string, string>) {

        // process.env.DEBUG = 'node-vault'; // switch on debug mode

        // this file was created when last logged in, and will exist unless token is recreated by K8s
        console.log("checking if already logged in")
        if (!fs.existsSync(this.loginCheckPath)) {
            await this.Login()
        }

        // create map to be returned
        let newMap = new Map<string, string>();

        // set up client to access vault`
        let client_options = {
            apiVersion: 'v1',
            endpoint: this.url,
            token: this.token,
            json: true
        };

        // create a vault access client
        let client_vault = require("node-vault")(client_options);

        // read the secret from Vault then get the value of the field requested and create an entry in the new Map
        // console.log("read the secret from Vault then get the value of the field requested and create an entry in the new Map");
        for (let key of vaultValues.keys()) {
            let splitKey = key.split('|');
            let temp = splitKey[0];
            let secret = temp.slice(0, 6) + "/data" + temp.slice(6);
            let field = splitKey[1];
            // console.log("the secret needed is "+secret+" and the field is "+field);
            // console.log("reading the secret from vault");
            await client_vault.read(secret).then((body) => {
                if (field != undefined) {
                    newMap.set(vaultValues.get(key), body.data.data[field]);
                    // console.log("vaultValues.get(key) is "+vaultValues.get(key))
                    // console.log("reading the field value from vault is "+body.data.data[field]);
                } else {
                    // console.log("no field provided to read from secret");
                    return new Error("no field provided to read from secret");
                }
            }).catch(console.error);
        }
        //return newMap;
        return Promise.resolve(newMap);
    }

    async Login() {
        // console.log("about to login to vault");

        await this.getVaultIp();

        await this.vaultLogin();

        // create file to indicate login has occurred for this instance of the token
        if (!fs.existsSync(this.loginCheckPath)) {
            // making login check directory
            // console.log("making login check directory: " + this.baseLoginCheckPath)
            let pwd = process.cwd()
            process.chdir(this.baseLoginCheckDir);

            // console.log("writing check file: " + this.tokenFilecheck + " in directory " + this.baseLoginCheckPath)
            // create file to indicate login has occurred for this instance of the token
            fs.closeSync(fs.openSync(this.tokenFilecheck, 'a'));

            process.chdir(pwd);
        }

        console.log("logged in")
    }

    async getVaultIp() {
        try {
            // define k8s cluster client
            const k8s = require('@kubernetes/client-node');
            const kc = new k8s.KubeConfig();
            kc.loadFromCluster();
            const k8sApi = kc.makeApiClient(k8s.CoreV1Api);

            // console.log("current k8s context is " + kc.currentContext);
            // kc.clusters.forEach(function (value) {
            //     console.log("the cluster name is: " + value.name);
            //     console.log("the cluster server is: " + value.server);
            //     console.log("the cluster caFile path is: " + value.caFile);
            // });
            // kc.contexts.forEach(function (value) {
            //     console.log("the context is: " + value.name);
            // });

            // get the IP address of the active node of HA Vault
            // Promise.all([k8sApi.listNamespacedPod('vault', null, null, null ,null, 'app:vault')])
            // let prom = k8sApi.listNamespacedPod('vault');
            // console.log("getting all the vault pods in the vault namespace");
            const getVaultPods = Promise.all([k8sApi.listNamespacedPod('vault', null, null, null ,null, 'app=vault')]);
            await getVaultPods.then((res) => {
                // console.log("list of response statusCode is " + res[0].response.statusCode);
                // console.log("list of response statusMessage is " + res[0].response.statusMessage);
                if (res[0].response.statusCode == 200) {
                    this.IP = res[0].body.items[0].status.podIP;
                    // console.log("vault IP is " + this.IP);
                    this.url = "http://" + this.IP + ":8200"
                } else {
                    return new Error("The response statusCode is " + res[0].response.statusCode + "and the response statusMessage is " + res[0].response.statusMessage)
                }
            });
        }
        catch (err) {
            console.log("k8sApi.listNamespacedPod rejected: ", err);
        }
    }

    async vaultLogin() {
        // set up client to access vault`
        let client_options = {
            apiVersion: 'v1',
            endpoint: this.url
        };

        // get new instance of the client
        let vault = require("node-vault")(client_options);

        try {
            // read the K8s generated token
            let jwt = fs.readFileSync(this.tokenPath, 'utf8');

            // login using the Kubernetes Auth method
            // console.log("logging into vault using jwt created for the service account");
            const login = Promise.all([vault.kubernetesLogin({role: this.roleName, jwt: jwt})]);
            await login.then((result) => {
                this.token = result[0].auth.client_token;
                // console.log("the access token is "+this.token);
            });
        }
        catch (err) {
            console.log("vault.kubernetesLogin rejected: ", err);
        }
    }
}
