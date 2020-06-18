package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	vault "github.com/hashicorp/vault/api"
	"gopkg.in/yaml.v2"
	"io/ioutil"
	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	_ "k8s.io/client-go/plugin/pkg/client/auth"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/tools/portforward"
	"k8s.io/client-go/transport/spdy"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

type Vault struct {
	Target    bool   `yaml:"target"`
	Env       string `yaml:"env"`
	Namespace string `yaml:"namespace"`
	K8s       bool   `yaml:"k8s"`
	Host      string `yaml:"host"`
	Port      int    `yaml:"port"`
	Podname   string `yaml:"podname"`
	Podport   int 	 `yaml:"podport"`
	Kubectx   string `yaml:"kubectx"`
}

type Vaults struct {
	Vaults []*Vault `yaml:"vaults"`
}

type readConf struct {
	env        string
	namespace  string
	k8s        bool
	host       string
	port       int
	podname    string
	podport    int
	kubectx    string
	sourceHost string
	sourcePort int
}

type PortForwardAPodRequest struct {
	// RestConfig is the kubernetes config
	RestConfig *rest.Config
	// Pod is the selected pod for this port forwarding
	Pod v1.Pod
	// LocalPort is the local port that will be selected to expose the PodPort
	LocalPort int
	// PodPort is the target port for the pod
	PodPort int
	// Steams configures where to write or read input from
	Out    bytes.Buffer
	ErrOut bytes.Buffer
	// StopCh is the channel used to manage the port forward lifecycle
	StopCh <-chan struct{}
	// ReadyCh communicates when the tunnel is ready to receive traffic
	ReadyCh chan struct{}
}

var readcf readConf
var authClient *vault.Client
var token = os.Getenv("vault_token")
var kubeconfig *string
var totalSecrets = 0

func main() {
	log.Print("local vault token is: " + token)

	f, err := os.Open("./config.yaml")
	if err != nil {
		log.Print("error opening the config file: " + err.Error())
	}
	defer f.Close()

	var config Vaults
	vaults, err := ioutil.ReadAll(f)
	if err != nil {
		panic(err.Error())
	}
	err = yaml.Unmarshal(vaults, &config)
	if err != nil {
		panic(err.Error())
	}
	//log.Print("config.Vaults[0].Env is :", config.Vaults[0].Env)

	for i, _ := range config.Vaults {
		if config.Vaults[i].Env == "dev" {
			readcf.sourceHost = config.Vaults[i].Host
			readcf.sourcePort = config.Vaults[i].Port
			if readcf.env != "" {
				break
			}
		}
		if config.Vaults[i].Target {
			readcf.env = config.Vaults[i].Env
			readcf.namespace = config.Vaults[i].Namespace
			readcf.k8s = config.Vaults[i].K8s
			readcf.host = config.Vaults[i].Host
			readcf.port = config.Vaults[i].Port
			readcf.podname = config.Vaults[i].Podname
			readcf.podport = config.Vaults[i].Podport
			readcf.kubectx = config.Vaults[i].Kubectx
			if readcf.sourceHost != "" {
				break
			}
		}
	}

	log.Print("env is :", readcf.env)
	log.Print("namespace is :", readcf.namespace)
	log.Print("k8s is :", readcf.k8s)
	log.Print("host is :", readcf.host)
	log.Print("port is :", readcf.port)
	log.Print("podname is :", readcf.podname)
	log.Print("kubectx is :", readcf.kubectx)
	log.Print("sourceHost is :", readcf.sourceHost)
	log.Print("sourcePort is :", readcf.sourcePort)

	var readResult = make(map[int]map[string]string)
	var writeResult = make(map[string]string)

	// load base secret
	rootSecret := "env/" + readcf.env + "/"

	//var loginErr error
	//token, loginErr = login()
	//if loginErr != nil {
	//	log.Print(loginErr)
	//}
	//log.Print("the token is ", token)

	readResult, err = readVaultSecret(readcf, rootSecret, true)
	if err != nil {
		log.Print("the error is ", err.Error())
		panic(err)
	}

	// the structure of map[int]map[string]string allows for sorting of the secrets in the order
	// they were inserted in. The range function doesn't guarantee this, and this is crucial.
	// if this wasn't the case you could find that the fields in a secret are written at different times
	// which could mean they are accidentally lost because of the Vault KV v2 versioning
	keys := make([]int, 0)
	for k, _ := range readResult {
		keys = append(keys, k)
	}
	sort.Ints(keys)
	for _, k := range keys {
		for key, value := range readResult[k] {
			log.Print("found key is: " + key + " value is: " + value + " index is " + strconv.Itoa(k))
		}
	}

	writeResult, err = writeVaultSecret(readResult)
	if err != nil {
		for keyRes, valueRes := range writeResult {
			log.Print("written key is: " + keyRes + " value is: " + valueRes)
		}
		panic(err)
	}

}

func readVaultSecret(readcf readConf, secret string, thread bool) (map[int]map[string]string, error) {
	var tempResult = make(map[int]map[string]string)
	var returnMap = make(map[int]map[string]string)
	var returnErr error
	var endSecretPath = false

	type ListResponse struct {
		requestId     string              `json:"request_id"`
		leaseId       string              `json:"lease_id"`
		renewable     bool                `json:"renewable"`
		leaseDuration int                 `json:"lease_duration"`
		Data          map[string][]string `json:"data"`
		wrapInfo      string              `json:"wrap_info"`
		warnings      string              `json:"warnings"`
		auth          string              `json:"auth,omitempty"`
	}

	//	log.Print("the secret path is ", secret)
	var protocol string
	log.Print("readcf.sourceHost is: " + readcf.sourceHost)
	if readcf.sourceHost == "localhost"  {
		protocol = "http://"
	}else {
		protocol = "https://"
	}
	c := &http.Client{}
	req, _ := http.NewRequest("GET", protocol+readcf.sourceHost+":"+strconv.Itoa(readcf.sourcePort)+"/v1/secret/metadata/"+fmt.Sprintf("%v", secret)+"?list=true", nil)
	req.Header.Set("X-Vault-Token", token)

	// get list of base secrets
	resp, err := c.Do(req)
	if err != nil {
		log.Print("error reading the root secret in the host vault")
		log.Print("the error is: " + err.Error())
		resp.Body.Close()
		returnErr = err
		return returnMap, returnErr
	}

	//respdump, err := httputil.DumpResponse(resp, true)
	//if err != nil {
	//	panic(err.Error())
	//}
	//log.Print("the error response body is: " + string(respdump))

	// there is no error if a response is sent, so check to see if it's a successful response
	if resp.StatusCode != 200 {
		//log.Printf("the response code is: %s, and the response status is: %s", resp.StatusCode, resp.Status)
		respdump, err := httputil.DumpResponse(resp, true)
		if err != nil {
			panic(err.Error())
		}
		log.Print("the error response body is: " + string(respdump))
		resp.Body.Close()
		if strings.Contains(resp.Status, "404") {
			returnErr = errors.New("couldn't find any secrets with the base you defined. please check the config")
		} else {
			returnErr = errors.New(resp.Status)
		}

		return returnMap, returnErr
	}

	// read in the response body and unmarshall to JSON
	var listResponse ListResponse
	body, err := ioutil.ReadAll(resp.Body)
	err = json.Unmarshal(body, &listResponse)
	if err != nil {
		log.Print("the error is: " + err.Error())
		resp.Body.Close()
		panic(err.Error())
	}

	log.Print("readcf.sourceHost is: " + readcf.sourceHost)

	authClient, err = vault.NewClient(&vault.Config{Address: protocol + readcf.sourceHost + ":" + strconv.Itoa(readcf.sourcePort)})
	if err != nil {
		panic(err)
	}

	// get the resultant list of secrets
	vaultSecrets := listResponse.Data["keys"]
	for _, vaultSecret := range vaultSecrets {
		if strings.HasSuffix(fmt.Sprintf("%v", vaultSecret), "/") {
			// append the previous path with the new suffix and keep looking
			//log.Printf("the secret so far is %v", secret+vaultSecret)
			tempResult, err = readVaultSecret(readcf, fmt.Sprintf("%v", secret+vaultSecret), false)
			if err != nil {
				panic(err)
			}
			// Copy from the temp map to the result map
			for k, _ := range tempResult {
				for key, value := range tempResult[k] {
					var tempMap = make(map[string]string)
					tempMap[key] = value
					returnMap[k] = tempMap
				}
			}

		} else {
			fullSecret := fmt.Sprintf("%v", "secret/data/"+secret+vaultSecret)
			//log.Print("the resulting secret path is ", fullSecret)
			authClient.SetToken(token)
			client := authClient.Logical()
			secretFields, readErr := client.Read(fullSecret)
			if readErr != nil {
				returnErr = readErr
				log.Print("Error reading the fields of " + fullSecret + " the error is " + readErr.Error())
				endSecretPath = true
			}

			//log.Print("the length of secretFields is " + strconv.Itoa(len(secretFields.Data)))
			for mapKey, mapVal := range secretFields.Data {
				//log.Printf("the returned data is %v and the field is %v", mapKey, mapVal)
				if mapKey == "data" {
					for field, value := range mapVal.(map[string]interface{}) {
						//log.Printf("the secret is %v and the field is %v", field, value)
						var tempMap = make(map[string]string)
						keystr := string(fullSecret + "|" + fmt.Sprintf("%v", field))
						tempMap[keystr] = fmt.Sprintf("%v", value)
						returnMap[totalSecrets] = tempMap
						//log.Print("the number of values in the returned Map is "+strconv.Itoa(len(returnMap)))
						totalSecrets++
						//log.Print("the stored value for the secret "+fullSecret+"|"+fmt.Sprintf("%v", field)+ " is "+returnMap[fullSecret+"|"+fmt.Sprintf("%v", field)])
					}
					break
				}
			}
			endSecretPath = true
		}
		if endSecretPath {
			break
		}
	}

	resp.Body.Close()

	//for field, value := range returnMap {
	//	log.Print("the returning value for the returning secret "+field+ " is "+value)
	//}
	return returnMap, returnErr
}

func writeVaultSecret(secrets map[int]map[string]string) (map[string]string, error) {
	var returnMap = make(map[string]string)
	var secretMap = make(map[string]interface{})
	var returnErr error
	var err error

	keys := make([]int, 0)
	for k, _ := range secrets {
		keys = append(keys, k)
	}
	sort.Ints(keys)

	var currentSecret = ""
	// set up kubectl port replication
	for _, k := range keys {
		for secretKey, secretVal := range secrets[k] {
			var splitKey = strings.Split(secretKey, string('|'))
			var secret = splitKey[0]

			//log.Print("secret is " + secret + " and currentSecret is " + currentSecret)
			//log.Print("len(secretMap) is " + strconv.Itoa(len(secretMap)))
			if len(secretMap) == 0 || secret == currentSecret {
				//log.Print("found field for same secret or first time")
				currentSecret = secret
				secretMap[secretKey] = secretVal
				// delete secret so that recursion doesn't use it again
				delete(secrets, k)
			} else {
				//log.Print("found field for new secret")
				writeResult, err := writeVaultSecret(secrets)
				if err != nil {
					returnErr = err
				}
				for resultKey, resultValue := range writeResult {
					returnMap[resultKey] = fmt.Sprintf("%v", resultValue)
				}
			}
		}
	}

	authClient, err = vault.NewClient(&vault.Config{Address: "http://" + readcf.host + ":" + strconv.Itoa(readcf.port)})
	if err != nil {
		panic(err)
	}

	// stopCh control the port forwarding lifecycle. When it gets closed the
	// port forward will terminate
	stopCh := make(chan struct{}, 1)
	// readyCh communicate when the port forward is ready to get traffic
	readyCh := make(chan struct{})
	// stream is used to tell the port forwarder where to place its output or
	// where to expect input if needed. For the port forwarding we just need
	// the output eventually
	out, errOut := new(bytes.Buffer), new(bytes.Buffer)

	if kubeconfig == nil {
		home, err := homeDir()
		if err != nil {
			panic(err.Error())
		} else if home != "" {
			kubeconfig = flag.String("kubeconfig", filepath.Join(home, ".kube", "config"), "(optional) absolute path to the kubeconfig file")
		} else {
			panic(errors.New("can't get the kubeconfig file"))
		}
		flag.Parse()
	}

	//log.Print("kubeconfig path is " + *kubeconfig)

	// use the current context in kubeconfig
	//config, err := clientcmd.BuildConfigFromFlags("", *kubeconfig)
	config, err := buildConfigFromFlags(readcf.kubectx, *kubeconfig)
	if err != nil {
		log.Print("error building kubeconfig from context " + err.Error())
		panic(err.Error())
	}

	// set up asynch go function to run the port forwarder
	go func() {
		err = PortForwardAPod(PortForwardAPodRequest{
			RestConfig: config,
			Pod: v1.Pod{
				ObjectMeta: metav1.ObjectMeta{
					Name:      readcf.podname,
					Namespace: readcf.namespace,
				},
			},
			LocalPort: readcf.port,
			PodPort:   readcf.podport,
			Out:       *out,
			ErrOut:    *errOut,
			StopCh:    stopCh,
			ReadyCh:   readyCh,
		})
		if err != nil {
			log.Print("error setting up port forwarding: " + err.Error())
			panic(err)
		}
	}()

	// wait until port forwarder is ready
	select {
	case <-readyCh:
		break
	}
	println("Port forwarding is ready to get traffic.")

	//log.Print("ready to write secret and fields")
	var writeData = make(map[string]interface{})
	var data = make(map[string]interface{})
	var writeSecret = ""
	//log.Print("length of returnMap is " + strconv.Itoa(len(returnMap)))
	for writeKey, writeValue := range secretMap {
		var splitKey = strings.Split(writeKey, string('|'))
		var keySecret = splitKey[0]
		var keyField = splitKey[1]
		keySecret = strings.Replace(keySecret, "/env/"+readcf.env, "", -1)

		// copy value outside the for-loop
		writeSecret = keySecret
		//log.Print("writeSecret is " + writeSecret + " keySecret is " + keySecret)
		log.Print("writeSecret is " + writeSecret + " keyField is " + keyField)
		data[keyField] = writeValue
	}

	writeData["data"] = data

	token := os.Getenv("target_token")
	//log.Print("the target_token is " + token)
	authClient.SetToken(token)
	client := authClient.Logical()

	//// delete the secret  - this stops multiple version building up even when the secret doesn't change
	//_, deleteErr := client.Delete(writeSecret)
	//if deleteErr != nil {
	//	returnMap[writeSecret+" result"] = deleteErr.Error()
	//	log.Print("Error writing the fields the error is " + deleteErr.Error())
	//	returnErr = deleteErr
	//} else {
	//	log.Print("the deleted Secret is " + fmt.Sprintf("%v", writeSecret))
	//}

	// create the secret
	writtenSecret, writeErr := client.Write(writeSecret, writeData)
	if writeErr != nil {
		returnMap[writeSecret+" result"] = writeErr.Error()
		log.Print("Error writing the fields the error is " + writeErr.Error())
		returnErr = writeErr
	} else {
		returnMap[writeSecret+" result"] = fmt.Sprintf("%v", writtenSecret.Data["created_time"])
		log.Print("the result for secret " + writeSecret + " is " + fmt.Sprintf("%v", writtenSecret.Data["created_time"]))
	}

	close(stopCh)
	return returnMap, returnErr
}

func login() (string, error) {

	type Metadata struct {
		org      string `json:"org"`
		username string `json:"username"`
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

	// creat the login JSON payload
	//values := map[string]string{"token": token}
	//jsonValue, _ := json.Marshal(values)
	//log.Printf("jsonValue is: %s", jsonValue)

	var protocol string
	log.Print("readcf.sourceHost is: " + readcf.sourceHost)
	if readcf.sourceHost == "localhost"  {
		protocol = "http://"
	}else {
		protocol = "https://"
	}
	log.Print("protocol is: " + protocol)

	// login to Vault
	c := &http.Client{}
	req, _ := http.NewRequest("POST", protocol+readcf.sourceHost+":"+strconv.Itoa(readcf.sourcePort)+"/v1/auth/token", nil)
	req.Header.Set("X-Vault-Token", token)

	// get list of base secrets
	resp, err := c.Do(req)
	//resp, err := http.Post(protocol+readcf.sourceHost+":"+strconv.Itoa(readcf.sourcePort)+"/v1/auth/token/login", "application/json", bytes.NewBuffer(jsonValue))
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

	log.Print("logged in")

	return token, nil
}

func PortForwardAPod(req PortForwardAPodRequest) error {
	path := fmt.Sprintf("/api/v1/namespaces/%s/pods/%s/portforward",
		req.Pod.Namespace, req.Pod.Name)

	hostIP := strings.TrimLeft(req.RestConfig.Host, "https://")
	log.Print("hostIP is : " + hostIP)
	log.Print("path is : " + path)

	transport, upgrader, err := spdy.RoundTripperFor(req.RestConfig)
	if err != nil {
		return err
	}

	dialer := spdy.NewDialer(upgrader, &http.Client{Transport: transport}, http.MethodPost, &url.URL{Scheme: "https", Path: path, Host: hostIP})
	fw, err := portforward.New(dialer, []string{fmt.Sprintf("%d:%d", req.LocalPort, req.PodPort)}, req.StopCh, req.ReadyCh, &req.Out, &req.ErrOut)
	if err != nil {
		return err
	}

	return fw.ForwardPorts()
}

func homeDir() (string, error) {
	if h := os.Getenv("HOME"); h != "" {
		return h, nil
	}
	return "", errors.New("Can't find the HOME dir")
}

func buildConfigFromFlags(context, kubeconfigPath string) (*rest.Config, error) {
	return clientcmd.NewNonInteractiveDeferredLoadingClientConfig(
		&clientcmd.ClientConfigLoadingRules{ExplicitPath: kubeconfigPath},
		&clientcmd.ConfigOverrides{
			CurrentContext: context,
		}).ClientConfig()
}
