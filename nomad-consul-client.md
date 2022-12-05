# Setup Nomad & Consul Client

## Importance note

Be aware that **a nomad client need to connect only consul client**. If you connect 2 nomad clients to the same consul client. This still seems run well until you deploy a service from Nomad, very unstable in my experience

## Setup [Name: node-client-1 <-> IP: 10.238.22.209]

0. Generate token for consul - nomad client token node ( run on any consul cluster node)

```bash
consul acl token create -description "Nomad Agent Client Token" -policy-name "nomad-client" | tee nomad-client-agent.token

#### OUTPUT #####
AccessorID:       05207edd-4eed-1a11-8300-6042f15eaefa
SecretID:         a872e6af-1757-b341-666e-ebe82de375a8 <==== Take note this key for later steps
Description:      Nomad Agent Client Token
Local:            false
Create Time:      2022-12-01 15:33:34.138137836 +0700 +07
Policies:
   9cc90b5e-1e79-60cf-0d03-b8213a227d01 - nomad-client

```
 
> ONLY DO STEP 1,2 IF YOU INSTALL ON PHYSICAL MACHINES
1. Copy backup **~/certs** from `node-cluster-1` to `node-client-1`

2. Run command 

```
sudo cp -R ~/certs/* /opt/consul/certs
sudo chown -R consul:consul /opt/consul && sudo chmod a+r -R /opt/consul/certs
```


3. Configuration

- **/etc/consul.d/consul.hcl**

```shell
sudo nano /etc/consul.d/consul.hcl

##### content #####
datacenter             = "saigon"
domain                 = "bssd.vn"
node_name              = "sg-agent-consul-1"
data_dir               = "/opt/consul"
encrypt                = "BNWu/UhiUQZMSHgAovDzGG/sCxohYpBS81nXoDhsND4=" ### Encrypt key from Step 1
verify_incoming        = true
verify_outgoing        = true
verify_server_hostname = true
ca_file                = "/opt/consul/certs/bssd.vn-agent-ca.pem"
cert_file              = "/opt/consul/certs/saigon-server-bssd.vn-0.pem"
key_file               = "/opt/consul/certs/saigon-server-bssd.vn-0-key.pem"

# Client don't have auto_encrypt properties. Remove or comment it
# auto_encrypt {
#   allow_tls = true
# }

retry_join = ["10.238.22.45", "10.238.22.50", "10.238.22.48"] ### List of all consul server ( CORE NODES )

acl {
  enabled                  = true
  default_policy           = "deny"
  enable_token_persistence = true
  tokens {
    agent = "d9ad679b-59a6-057e-3de3-9a59a254f60d"
  }
}

performance {
  raft_multiplier = 1
}
```

- **/etc/consul.d/server.hcl**

```bash
sudo nano /etc/consul.d/server.hcl

##### content #####
# Consul client doesn't need config for server
# server           = true
# bootstrap_expect = 3
bind_addr        = "10.238.22.209"
client_addr      = "0.0.0.0"
connect {
  enabled = true
}
addresses {
  grpc = "127.0.0.1"
}
ports {
  grpc = 8502
}
ui_config {
  enabled = true
}
```

4. Start service

```bash
sudo systemctl restart consul
sudo systemctl status consul
```

### Setup nomad

1. Configuration

- **/etc/nomad.d/nomad.hcl**

```bash
sudo nano /etc/nomad.d/nomad.hcl

##### content #####
datacenter = "saigon"
data_dir   = "/opt/nomad"
bind_addr  = "10.238.22.209"
acl {
  enabled = true
}
# used for prometheus
telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}
# setting docker plugin
plugin "docker" {
  config {
    endpoint = "unix:///var/run/docker.sock"
    volumes {
      enabled      = true
      selinuxlabel = "z"
    }
    extra_labels = ["job_name", "job_id", "task_group_name", "task_name", "namespace", "node_name", "node_id"]

    gc {
      image       = true
      image_delay = "10m"
      container   = true

      dangling_containers {
        enabled        = true
        dry_run        = false
        period         = "5m"
        creation_grace = "5m"
      }
    }
    allow_privileged = true
    
  }
}
```

- **/etc/nomad.d/server.hcl**

```bash
sudo nano /etc/nomad.d/server.hcl

##### content #####
server {
  enabled          = false
}
```

- **/etc/nomad.d/client.hcl**

```bash
sudo nano /etc/nomad.d/client.hcl

##### content #####
client {
  enabled    = true
  node_class = "agent"
  server_join {
    #NOMAD SERVER LIST
    retry_join = ["10.238.22.45:4647", "10.238.22.50:4647", "10.238.22.48:4647"]
  }
}
```

- **/etc/nomad.d/consul.hcl**

```bash
sudo nano /etc/nomad.d/consul.hcl

##### content #####
consul {
  address = "127.0.0.1:8500"
  # server_service_name = "sg-agent-nomad-server-1"
  client_service_name = "sg-agent-nomad-client-1"
  auto_advertise = true
  # server_auto_join = true
  client_auto_join = true
  token               = "a872e6af-1757-b341-666e-ebe82de375a8" # SecretID from step 0
}
```
2. Start service

```bash
sudo systemctl restart nomad && sudo systemctl status nomad
```

## Setup [Name: node-client-2 <-> IP: 10.238.22.137]
 
> ONLY DO STEP 1,2 IF YOU INSTALL ON PHYSICAL MACHINES
1. Copy backup **~/certs** from `node-cluster-1` to `node-client-2`

2. Run command 

```
sudo cp -R ~/certs/* /opt/consul/certs
sudo chown -R consul:consul /opt/consul && sudo chmod a+r -R /opt/consul/certs
```


3. Configuration

- **/etc/consul.d/consul.hcl**

```shell
sudo nano /etc/consul.d/consul.hcl

##### content #####
datacenter             = "saigon"
domain                 = "bssd.vn"
node_name              = "sg-agent-consul-2"
data_dir               = "/opt/consul"
encrypt                = "BNWu/UhiUQZMSHgAovDzGG/sCxohYpBS81nXoDhsND4=" ### Encrypt key from Step 1
verify_incoming        = true
verify_outgoing        = true
verify_server_hostname = true
ca_file                = "/opt/consul/certs/bssd.vn-agent-ca.pem"
cert_file              = "/opt/consul/certs/saigon-server-bssd.vn-0.pem"
key_file               = "/opt/consul/certs/saigon-server-bssd.vn-0-key.pem"

retry_join = ["10.238.22.45", "10.238.22.50", "10.238.22.48"] ### List of all consul server ( CORE NODES )

acl {
  enabled                  = true
  default_policy           = "deny"
  enable_token_persistence = true
  tokens {
    agent = "d9ad679b-59a6-057e-3de3-9a59a254f60d"
  }
}

performance {
  raft_multiplier = 1
}
```

- **/etc/consul.d/server.hcl**

```bash
sudo nano /etc/consul.d/server.hcl

##### content #####
bind_addr        = "10.238.22.137"
client_addr      = "0.0.0.0"
connect {
  enabled = true
}
addresses {
  grpc = "127.0.0.1"
}
ports {
  grpc = 8502
}
ui_config {
  enabled = true
}
```

4. Start service

```bash
sudo systemctl restart consul
sudo systemctl status consul
```

### Setup nomad

1. Configuration

- **/etc/nomad.d/nomad.hcl**

```bash
sudo nano /etc/nomad.d/nomad.hcl

##### content #####
datacenter = "saigon"
data_dir   = "/opt/nomad"
bind_addr  = "10.238.22.137"
acl {
  enabled = true
}
# used for prometheus
telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}
# setting docker plugin
plugin "docker" {
  config {
    endpoint = "unix:///var/run/docker.sock"
    volumes {
      enabled      = true
      selinuxlabel = "z"
    }
    extra_labels = ["job_name", "job_id", "task_group_name", "task_name", "namespace", "node_name", "node_id"]

    gc {
      image       = true
      image_delay = "10m"
      container   = true

      dangling_containers {
        enabled        = true
        dry_run        = false
        period         = "5m"
        creation_grace = "5m"
      }
    }
    allow_privileged = true
    
  }
}
```

- **/etc/nomad.d/server.hcl**

```bash
sudo nano /etc/nomad.d/server.hcl

##### content #####
server {
  enabled          = false
}
```

- **/etc/nomad.d/client.hcl**

```bash
sudo nano /etc/nomad.d/client.hcl

##### content #####
client {
  enabled    = true
  node_class = "agent"
  server_join {
    #NOMAD SERVER LIST
    retry_join = ["10.238.22.45:4647", "10.238.22.50:4647", "10.238.22.48:4647"]
  }
}
```

- **/etc/nomad.d/consul.hcl**

```bash
sudo nano /etc/nomad.d/consul.hcl

##### content #####
consul {
  address             = "127.0.0.1:8500"
  client_service_name = "sg-agent-nomad-client-2"
  auto_advertise      = true
  client_auto_join    = true
  token               = "a872e6af-1757-b341-666e-ebe82de375a8"
}
```
2. Start service

```bash
sudo systemctl restart nomad && sudo systemctl status nomad
```

## Setup [Name: node-client-3 <-> IP: 10.238.22.191]
 
> ONLY DO STEP 1,2 IF YOU INSTALL ON PHYSICAL MACHINES
1. Copy backup **~/certs** from `node-cluster-1` to `node-client-3`

2. Run command 

```
sudo cp -R ~/certs/* /opt/consul/certs
sudo chown -R consul:consul /opt/consul && sudo chmod a+r -R /opt/consul/certs
```

3. Configuration

- **/etc/consul.d/consul.hcl**

```shell
sudo nano /etc/consul.d/consul.hcl

##### content #####
datacenter             = "saigon"
domain                 = "bssd.vn"
node_name              = "sg-agent-consul-3"
data_dir               = "/opt/consul"
encrypt                = "BNWu/UhiUQZMSHgAovDzGG/sCxohYpBS81nXoDhsND4=" ### Encrypt key from Step 1
verify_incoming        = true
verify_outgoing        = true
verify_server_hostname = true
ca_file                = "/opt/consul/certs/bssd.vn-agent-ca.pem"
cert_file              = "/opt/consul/certs/saigon-server-bssd.vn-0.pem"
key_file               = "/opt/consul/certs/saigon-server-bssd.vn-0-key.pem"

retry_join = ["10.238.22.45", "10.238.22.50", "10.238.22.48"] ### List of all consul server ( CORE NODES )

acl {
  enabled                  = true
  default_policy           = "deny"
  enable_token_persistence = true
  tokens {
    agent = "d9ad679b-59a6-057e-3de3-9a59a254f60d"
  }
}

performance {
  raft_multiplier = 1
}
```

- **/etc/consul.d/server.hcl**

```bash
sudo nano /etc/consul.d/server.hcl

##### content #####
bind_addr        = "10.238.22.191"
client_addr      = "0.0.0.0"
connect {
  enabled = true
}
addresses {
  grpc = "127.0.0.1"
}
ports {
  grpc = 8502
}
ui_config {
  enabled = true
}
```

4. Start service

```bash
sudo systemctl restart consul
sudo systemctl status consul
```

### Setup nomad

1. Configuration

- **/etc/nomad.d/nomad.hcl**

```bash
sudo nano /etc/nomad.d/nomad.hcl

##### content #####
datacenter = "saigon"
data_dir   = "/opt/nomad"
bind_addr  = "10.238.22.191"
acl {
  enabled = true
}
# used for prometheus
telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}
# setting docker plugin
plugin "docker" {
  config {
    endpoint = "unix:///var/run/docker.sock"
    volumes {
      enabled      = true
      selinuxlabel = "z"
    }
    extra_labels = ["job_name", "job_id", "task_group_name", "task_name", "namespace", "node_name", "node_id"]

    gc {
      image       = true
      image_delay = "10m"
      container   = true

      dangling_containers {
        enabled        = true
        dry_run        = false
        period         = "5m"
        creation_grace = "5m"
      }
    }
    allow_privileged = true
    
  }
}
```

- **/etc/nomad.d/server.hcl**

```bash
sudo nano /etc/nomad.d/server.hcl

##### content #####
server {
  enabled          = false
}
```

- **/etc/nomad.d/client.hcl**

```bash
sudo nano /etc/nomad.d/client.hcl

##### content #####
client {
  enabled    = true
  node_class = "agent"
  server_join {
    #NOMAD SERVER LIST
    retry_join = ["10.238.22.45:4647", "10.238.22.50:4647", "10.238.22.48:4647"]
  }
}
```

- **/etc/nomad.d/consul.hcl**

```bash
sudo nano /etc/nomad.d/consul.hcl

##### content #####
consul {
  address             = "127.0.0.1:8500"
  client_service_name = "sg-agent-nomad-client-3"
  auto_advertise      = true
  client_auto_join    = true
  token               = "a872e6af-1757-b341-666e-ebe82de375a8"
}
```
2. Start service

```bash
sudo systemctl restart nomad && sudo systemctl status nomad
```

# Setup [Name: node-monitor <-> IP: 10.238.22.160]
 
> ONLY DO STEP 1,2 IF YOU INSTALL ON PHYSICAL MACHINES
1. Copy backup **~/certs** from `node-cluster-1` to `node-monitor`

2. Run command 

```
sudo cp -R ~/certs/* /opt/consul/certs
sudo chown -R consul:consul /opt/consul && sudo chmod a+r -R /opt/consul/certs
```

3. Configuration

- **/etc/consul.d/consul.hcl**

```shell
sudo nano /etc/consul.d/consul.hcl

##### content #####
datacenter             = "saigon"
domain                 = "bssd.vn"
node_name              = "sg-agent-monitor"
data_dir               = "/opt/consul"
encrypt                = "BNWu/UhiUQZMSHgAovDzGG/sCxohYpBS81nXoDhsND4=" ### Encrypt key from Step 1
verify_incoming        = true
verify_outgoing        = true
verify_server_hostname = true
ca_file                = "/opt/consul/certs/bssd.vn-agent-ca.pem"
cert_file              = "/opt/consul/certs/saigon-server-bssd.vn-0.pem"
key_file               = "/opt/consul/certs/saigon-server-bssd.vn-0-key.pem"

retry_join = ["10.238.22.45", "10.238.22.50", "10.238.22.48"] ### List of all consul server ( CORE NODES )

acl {
  enabled                  = true
  default_policy           = "deny"
  enable_token_persistence = true
  tokens {
    agent = "d9ad679b-59a6-057e-3de3-9a59a254f60d"
  }
}

performance {
  raft_multiplier = 1
}
```

- **/etc/consul.d/server.hcl**

```bash
sudo nano /etc/consul.d/server.hcl

##### content #####
bind_addr        = "10.238.22.160"
client_addr      = "0.0.0.0"
connect {
  enabled = true
}
addresses {
  grpc = "127.0.0.1"
}
ports {
  grpc = 8502
}
ui_config {
  enabled = true
}
```

4. Start service

```bash
sudo systemctl restart consul
sudo systemctl status consul
```

### Setup nomad

1. Configuration

- **/etc/nomad.d/nomad.hcl**

```bash
sudo nano /etc/nomad.d/nomad.hcl

##### content #####
datacenter = "saigon"
data_dir   = "/opt/nomad"
bind_addr  = "10.238.22.160"
acl {
  enabled = true
}
# used for prometheus
telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}
# setting docker plugin
plugin "docker" {
  config {
    endpoint = "unix:///var/run/docker.sock"
    volumes {
      enabled      = true
      selinuxlabel = "z"
    }
    extra_labels = ["job_name", "job_id", "task_group_name", "task_name", "namespace", "node_name", "node_id"]

    gc {
      image       = true
      image_delay = "10m"
      container   = true

      dangling_containers {
        enabled        = true
        dry_run        = false
        period         = "5m"
        creation_grace = "5m"
      }
    }
    allow_privileged = true
    
  }
}
```

- **/etc/nomad.d/server.hcl**

```bash
sudo nano /etc/nomad.d/server.hcl

##### content #####
server {
  enabled          = false
}
```

- **/etc/nomad.d/client.hcl**

```bash
sudo nano /etc/nomad.d/client.hcl

##### content #####
client {
  enabled    = true
  node_class = "monitor"
  server_join {
    #NOMAD SERVER LIST
    retry_join = ["10.238.22.45:4647", "10.238.22.50:4647", "10.238.22.48:4647"]
  }
}
```

- **/etc/nomad.d/consul.hcl**

```bash
sudo nano /etc/nomad.d/consul.hcl

##### content #####
consul {
  address             = "127.0.0.1:8500"
  client_service_name = "sg-agent-monitor"
  auto_advertise      = true
  client_auto_join    = true
  token               = "a872e6af-1757-b341-666e-ebe82de375a8"
}
```
2. Start service

```bash
sudo systemctl restart nomad && sudo systemctl status nomad
```
