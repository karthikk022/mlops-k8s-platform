ui = true
api_addr = "http://vault-active.vault-internal:8200"
cluster_addr = "https://vault-active.vault-internal:8201"

storage "raft" {
  path = "/vault/data"
  node_id = "vault-0"

  retry_join {
    leader_api_addr = "http://vault-0.vault-internal:8200"
  }
  retry_join {
    leader_api_addr = "http://vault-1.vault-internal:8200"
  }
  retry_join {
    leader_api_addr = "http://vault-2.vault-internal:8200"
  }
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_disable   = true
  cluster_address = "0.0.0.0:8201"
}

seal "awskms" {
  region     = "ap-south-1"
  kms_key_id = "alias/vault-unseal-key"
}

telemetry {
  prometheus_retention_time = "24h"
  disable_hostname          = true
}
