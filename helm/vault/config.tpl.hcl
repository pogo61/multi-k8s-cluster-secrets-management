ui = true

listener "tcp" {
  tls_disable     = 1
  address         = "[::]:8200"
  cluster_address = "[::]:8201"
}

storage "consul" {
  path    = "vault/"
  address = "HOST_IP:8500"
}

seal "gcpckms" {
  project    = "{{ .Env.PROJECT }}"
  region     = "{{ .Env.REGION }}"
  key_ring   = "vault-helm-unseal-kr-{{ .Env.WORKSPACE }}"
  crypto_key = "vault-helm-unseal-key"
}
