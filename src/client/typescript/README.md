# Vault Config Factory in Typescript

## Description
This utility wraps all interactions with the Hashicorp Vault instance in the Kubernetes Cluster an application is running in. 
Any Application/Service that requires secrets to access other components in the environment, or configs saved in Vault, 
can call this factory with a Map of what is required and it will return a map with those values.

## Related Repositories
The is a sister repo called https://gitlab.com/Beamery/DevOps/go_configfactory which is the same factory implemented in GoLang. 

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
    