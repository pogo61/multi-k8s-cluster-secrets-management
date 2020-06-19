# Vault Config Factory in Typescript

## Description
This utility wraps all interactions with the Hashicorp Vault instance in the Kubernetes Cluster an application is running in. 
Any Application/Service that requires secrets to access other components in the environment, or configs saved in Vault, 
can call this factory with a Map of what is required and it will return a map with those values.


## Build and Configuration
* import {ConfigFactory} from "./ConfigFactory";  //note this will change when ConfigFactory is packaged properly

## Usage
Refer to VaultTest.ts for an example of use. 
The following is a step-by-step explanation of this code:
1. Create and populate a Map with secrets/config you require
    ```
    let vaultVars = new Map();
    vaultVars.set("secret/data/exampleapp/config|token","token"); 
    ```
   Note: the 'key' of the map should be the path of the secret/config in Vault, and the 'value' is what you want the returned value to be known as for future use inyour code. 
   
   So, the value returned for `secret/data/exampleapp/config` with a field of `token` will be placed in the resulting Map key of `token`.
         
   Note also the `|` character between the secret and the field. this is important. Failure to do this will result in the factory failing.
   
   You can add as many map records as you need secrets or configs returned
   
 2. Create  the configfactory object
 
    ```
    let config = new ConfigFactory();
    ```
    
 3. Call the createVars method of the factory passing in the Map you have just created
  
    ```
    const confVars: Promise<Map<string, string>[]> = Promise.all([config.createVars(vaultVars)]);
    ```
    
 4. wait for the promise to complete and then do what you want with the resulting returned secrets/configs
 
    ```
    confVars.then((result) => {
         for (let key of result[0].keys()) {
             console.log("key is: "+ key +" value is: " + result[0].get(key));
         }
    });
    ```
    Giving that you are making an asynch invocation of this method, it might be prudent to prefix the use if the promise with the `await` directive.
   
## Testing
The files in the test directory will run the VaultTest.ts app that uses the configfactory Library.
The steps to run and test both the configfactory wrapper, and the Vault Slave that it uses are:
1. edit and change the main.go file to point to the secret(s) that have been replicated into your target slave.
(see step one of the Usage section).
2. build the container with the Dockerfile tagging the image to suit the repo it will be added to.     
e.g.   `docker build . -t paulpog/config_factory_js:latest`
3. push the image to the requisite docker repo that you have logged into.  
e.g. `docker push paulpog/config_factory_js:latest`
4. start the kubctl port forwarding to the K8s cluster supporting the Vault Slave. Remember the Slave will run in the 'vault' namespace.  
e.g. ` kubectl port-forward "vault-0" 9200:8200 -n vault`
5. login to the Vault Slave using the Slave's root token stored in /secret/vault/`environment` of the Master Vault  
e.g. `vault login token=<root.token>` 
6. define the K8s RBAC Role and RoleBinding to the K8s cluster supporting the Vault  
e.g. ` kubectl apply -f test/role.yaml` and  `kubectl apply -f test/roleBinding.yaml`
7. edit the deployment.yaml file and point to the image created in step 3.
8. run the test app `test/deploy.sh`
9. check the log of the Pod of the cf-test deployment in the K8s cluster for the results    