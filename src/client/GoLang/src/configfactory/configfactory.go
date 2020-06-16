package configfactory

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	vault "github.com/hashicorp/vault/api"
	"io/ioutil"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	kubernetes "k8s.io/client-go/kubernetes"
	rest "k8s.io/client-go/rest"
	"log"
	"net/http"
	"net/http/httputil"
	"os"
	"strings"
)

var token = *new(string)
var IP = *new(string)
var baseTokenPath = "/var/run/secrets/kubernetes.io/serviceaccount/"
var baseLoginCheckDir = "/tmp/"
var LoginCheckDir = "configFactory/"
var baseLoginCheckPath = baseLoginCheckDir + LoginCheckDir
var tokenFile = "token"
var tokenFilecheck = "loggedIn"
var tokenPath = baseTokenPath + tokenFile
var loginCheckPath = baseLoginCheckPath + tokenFilecheck

func check(e error) {
	if e != nil {
		panic(e)
	}
}

// fileExists checks if a file exists and is not a directory before we
// try using it to prevent further errors.
func FileExists(filename string) bool {
	info, err := os.Stat(filename)
	if os.IsNotExist(err) {
		return false
	}
	return !info.IsDir()
}

func CreateVars(vaultValues map[string]string) (map[string]string, error) {

	// this file was created when last logged in, and will exist unless token is recreated by K8s
	if !FileExists(loginCheckPath) {
		var err error
		token, err = login()
		if err != nil {
			log.Print(err)
			return nil, err
		}
	}

	authClient, err := vault.NewClient(&vault.Config{Address: "http://" + IP + ":8200"})
	authClient.SetToken(token)
	if err != nil {
		panic(err)
	}

	var tempMap = make(map[string]string)
	var newMap = make(map[string]string)

	// Copy from the original map to the target map
	for key, value := range vaultValues {
		tempMap[key] = value
	}

	// read the secret from Vault then get the value of the field requested and create an entry in the new Map
	for reqKey, reqValue := range tempMap {
		var splitKey = strings.Split(reqKey, string('|'))
		var temp = splitKey[0]
		var secret = strings.Replace(temp, "/secret", "/secret/data", 1)
		var reqField = splitKey[1]

		c := authClient.Logical()
		secretValues, err := c.Read(secret)
		if err != nil {
			log.Print(err)
		}

		for mapKey, mapVal := range secretValues.Data {
			if mapKey == "data" {
				for field, value := range mapVal.(map[string]interface{}) {
					if reqField != "" {
						if reqField == field {
							newMap[reqValue] = fmt.Sprintf("%v", value)
						}
					} else {
						log.Print("the secret must have a field defined")
						panic(errors.New("the secret must have a field defined"))
					}
				}
				break
			}
		}
	}

	return newMap, nil
}

func login() (string, error) {

	type Metadata struct {
		role                     string `json:"role"`
		serviceAccountName       string `json:"service_account_name"`
		serviceAccountNamespace  string `json:"service_account_namespace"`
		serviceAccountSecretName string `json:"service_account_secret_name"`
		serviceAccountUid        string `json:"service_account_uid"`
	}

	type Auth struct {
		ClientToken   string    `json:"client_token"`
		accessor      string    `json:"accessor"`
		policies      *[]string `json:"policies"`
		tokenpolicies *[]string `json:"token_policies"`
		metadata      *Metadata `json:"metadata"`
		leaseDuration int       `json:"lease_duration"`
		renewable     bool      `json:"renewable"`
		entityId      string    `json:"entity_id"`
		tokentype     string    `json:"token_type"`
		orphan        bool      `json:"orphan"`
	}

	type LoginResponse struct {
		requestId     string `json:"request_id"`
		leaseId       string `json:"lease_id"`
		renewable     bool   `json:"renewable"`
		leaseDuration int    `json:"lease_duration"`
		data          string `json:"data"`
		wrapInfo      string `json:"wrap_info"`
		warnings      string `json:"warnings"`
		Auth          *Auth  `json:"auth"`
	}

	// creates the in-cluster config
	config, err := rest.InClusterConfig()
	if err != nil {
		panic(err.Error())
	}
	// creates the clientset
	clientSet, err := kubernetes.NewForConfig(config)
	if err != nil {
		panic(err.Error())
	}

	// get the IP address of the active node of HA Vault
	pods, err := clientSet.CoreV1().Pods("vault").List(metav1.ListOptions{FieldSelector: "metadata.name=vault-0"})
	if err != nil {
		panic(err.Error())
	}
	IP = pods.Items[0].Status.PodIP

	// Read the jwt for the service account created by K8s
	content, err := ioutil.ReadFile(tokenPath)
	if err != nil {
		log.Fatal(err)
	}

	// remove leading and trailing whitespace
	jwt := strings.TrimSpace(string(content))

	// creat the login JSON payload
	values := map[string]string{"jwt": string(jwt), "role": "cf-test"}
	jsonValue, _ := json.Marshal(values)

	// login to Vault
	resp, err := http.Post("http://"+IP+":8200/v1/auth/kubernetes/login", "application/json", bytes.NewBuffer(jsonValue))
	if err != nil {
		panic(err.Error())
	}

	defer resp.Body.Close()

	// there is no error if a response is sent, so check to see if it's a successful response
	if resp.StatusCode != 200 {
		log.Printf("the response code is: %s, and the response status is: %s", resp.StatusCode, resp.Status)
		respdump, err := httputil.DumpResponse(resp, true)
		if err != nil {
			panic(err.Error())
		}
		log.Print("the error response body is: " + string(respdump))
		panic(errors.New(resp.Status))
	}

	// read in the response body and unmarshall to JSON
	var authResponse LoginResponse
	body, err := ioutil.ReadAll(resp.Body)
	err = json.Unmarshal(body, &authResponse)
	if err != nil {
		panic(err.Error())
	}

	// get the temp access token
	token := authResponse.Auth.ClientToken

	// create file to indicate login has occurred for this instance of the token
	if !FileExists(loginCheckPath) {
		log.Print("checking if the check directory exists")
		if _, err := os.Stat(baseLoginCheckPath); os.IsNotExist(err) {
			os.Chdir(baseLoginCheckDir)
			os.Mkdir(LoginCheckDir, 0755)
		}

		_, err := os.Create(loginCheckPath)
		if err != nil {
			log.Fatal(err)
		}
	}

	log.Print("logged in")

	return token, nil
}
