package main

import (
	"fmt"
	"github.com/pogo61/multi-k8s-cluster-secrets-management/src/client/GoLang/configfactory"
	"log"
)

func main() {
	log.Print("starting test")
	var vaultVars = make(map[string]string)
	vaultVars["/secret/google/api|token"] = "api-token"

	for i := 1; i < 5; i++ {
		confVars, err := configfactory.CreateVars(vaultVars)
		if err != nil {
			fmt.Println(err)
		}

		if confVars != nil {
			//log.Print("number of returned secrets is "+strconv.Itoa(len(confVars)))
			for key, value := range confVars {
				fmt.Println("key is: " + key + " value is: " + value)
			}
			log.Print("")
		} else {
			log.Print("something went wrong as there are no returned vars")
		}
	}
}
