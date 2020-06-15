# Vault Secret Replicator

## Description
The main use case for this is to define Production, Canary, Preview, etc secret branches in vault.engineer, and have them replicated to the vault instances in those environments. 
This will allow Devs to define their own secrets

## Architecture
![pic](Secrets%20Management%20Replication.png)

## Usage
Let's assume you want to create a secret for an API token, and you need to use it in preview, canary, and production:
1. login in to `https://vault.global.beamery.engineer` and create a secret called `preview/google/api` and call the field `token`, 
and it's value the value of the token you need in preview 
(assuming it is different to the values in the other environments). It should look like:
![pic](create%20preview%20token.png)
2. Do the same for the secret and value you want in Canary, except this secret will be called `canary/google/api`
3. Do the same for the secret and value you want in Production, except this secret will be called `production/google/api`

That's it!

The vault-replicator pipeline runs regularly and copies all secrets under /secret/preview to the preview Vault instance.

This is the same for /secret/canary and /secret/production. 

In the above example the secret in is called `/google/api` in all the environments

## Configuration
![pic](replicator%20config.png)

Every task in the pipeline will use a configuration like this above. This is looked after by the Platform team.

* If the target value is `false` it is assumed the source.
* all targets (because their vault instances are not exposed outside the K8s cluster) are accessed via \
 a kubectl port-forward. However the `k8s` value of true forces the replicator to use port-forwarding
* The `env` value points the replicator at the target vault instance
* The `kubectx` value is important as it allows the replicator to use the address and credentials to port-forward to the pod in the cluster



