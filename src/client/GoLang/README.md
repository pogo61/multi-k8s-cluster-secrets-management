# Vault Config Factory in GoLang

## Description
This utility wraps all interactions with the Hashicorp Vault instance in the Kubernetes Cluster an application is running in. 
Any Application/Service that requires secrets to access other components in the environment, or configs saved in Vault, 
can call this factory with a Map of what is required and it will return a map with those values.


## Build and Configuration
* import the configfactory module
    ```
  import (
  	"configfactory/configfactory" //note this will change when ConfigFactory is packaged properly
  	"fmt"
  	"log"
  )
  ```
   

## Usage
Refer to main.go for an example of use. 
The following is a step-by-step explanation of this code:
1. Create and populate a Map with secrets/config you require
    ```
    var vaultVars = make(map[string]string)
    vaultVars["/secret/data/exampleapp/config|token"] = "token" 
    ```
   Note: the 'key' of the map should be the path of the secret/config in Vault, and the 'value' is what you want the returned value to be known as for future use inyour code. 
   
   So, the value returned for `secret/data/exampleapp/config` with a field of `token` will be placed in the resulting Map key of `token`.
         
   Note also the `|` character between the secret and the field. this is important. Failure to do this will result in the factory failing.
   
   You can add as many map records as you need secrets or configs returned
    
 2. Call the createVars method of the factory passing in the Map you have just created
  
    ```
    confVars, err := configfactory.CreateVars(vaultVars)
    if err != nil {
    	fmt.Println(err)
    }
    ```
    
 3. if no errors were returned, do what you want with the resulting returned secrets/configs
 
    ```
    if confVars != nil {
    	for key, value := range confVars {
    		fmt.Println("key is: " + key + " value is: " + value)
    	}
    } else {
    	log.Print("something went wrong as there are no returned vars")
    }
    ```