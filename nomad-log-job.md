# DEPLOY LOG MONITOR
## Prepare mount volumes
1. Create directory for mount **fluentd**
> Fluentd run on all nodes, make sure you do this thing on all nodes too.

```shell
#### FLUENTD LOG DATA ####
sudo mkdir -p /nomad/volumes/fluent-data/log
sudo chown -R 100:101 /nomad/volumes/fluent-data
````

- Update nomad client configuration

```hcl
sudo nano /etc/nomad.d/client.hcl
client {
  enabled    = true
  node_class = "monitor"
  server_join {
    #NOMAD SERVER LIST
    retry_join = ["10.238.22.129:4647", "10.238.22.225:4647", "10.238.22.130:46>
  }
    
  .... 
  # Add this config #
  host_volume "fluent-data-log" {
    path      = "/nomad/volumes/fluent-data/log"
    read_only = false
  }
}
```

2. Create directory for mount **ELK** (ELK tend to run on **monitor node only**)

```shell
##### ELS DATA ######
sudo mkdir -p /nomad/volumes/elasticsearch-data
sudo chown -R 1000:0 /nomad/volumes/elasticsearch-data
##### KIBANA DATA #####
sudo mkdir -p /nomad/volumes/kibana-data
sudo chown -R 1000:0 /nomad/volumes/kibana-data
```
- Update nomad client configuration

```hcl
sudo nano /etc/nomad.d/client.hcl
client {
  enabled    = true
  node_class = "monitor"
  server_join {
    #NOMAD SERVER LIST
    retry_join = ["10.238.22.129:4647", "10.238.22.225:4647", "10.238.22.130:46>
  }
    
  .... 
  # Add this config #
  host_volume "elasticsearch-data" {
    path      = "/nomad/volumes/elasticsearch-data"
    read_only = false
  }
  host_volume "kibana-data" {
    path      = "/nomad/volumes/kibana-data"
    read_only = false
  }
}
```

3. Restart nomad 
### Deploy Elastic - Kibana

```hcl
job "log-monitor" {
  datacenters = ["saigon"]
  type        = "service"

  update {
    stagger      = "10s"
    max_parallel = 1
  }

  group "elk" {
    count = 1

    volume "els-data" {
      type      = "host"
      source    = "elasticsearch-data"
      read_only = false
    }

    volume "kibana-data" {
      type      = "host"
      source    = "kibana-data"
      read_only = false
    }


    restart {
      attempts = 2
      interval = "1m"
      delay    = "15s"
      mode     = "delay"
    }

    task "elasticsearch" {
      driver = "docker"
      constraint {
        attribute = "${node.class}"
        operator  = "="
        value     = "monitor"
      }
      volume_mount {
        volume      = "els-data"
        destination = "/usr/share/elasticsearch/data"
      }
      config {
        image = "elasticsearch:7.17.7"
        port_map = {
          http = 9200
        }
      }
      env = {
        "discovery.type" = "single-node"
        "bootstrap.memory_lock"="true"
        "ELASTIC_PASSWORD"="elastic"
        "xpack.security.enabled"="true"
        "KIBANA_SYSTEM_PASSWORD"="kibana"
      }

      service {
        name = "${TASKGROUP}-elasticsearch"
        port = "http"
        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        cpu    = 500
        memory = 2048
        network {
          mbits = 10
          port "http" {
            static = 9200
          }
        }
      }
    }

    task "kibana" {
      driver = "docker"
      constraint {
        attribute = "${node.class}"
        operator  = "="
        value     = "monitor"
      }
      volume_mount {
        volume      = "kibana-data"
        destination = "/usr/share/kibana/data"
      }
      config {
        image = "kibana:7.17.7"
        port_map = {
          kibanahttp = 5601
        }
      }
      env = {
        "ELASTICSEARCH_HOSTS" = "http://${NOMAD_IP_kibanahttp}:9200"
        "ELASTICSEARCH_USERNAME"="elastic"
        "ELASTIC_PASSWORD"="elastic"
        "KIBANA_SYSTEM_PASSWORD"="kibana"
      }
      service {
        name = "${TASKGROUP}-kibana"
        port = "kibanahttp"
        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }
      resources {
        cpu    = 500
        memory = 2048
        network {
          mbits = 10
          port "kibanahttp" {
            static = 5601
          }
        }
      }

    }
  }
}
```


### Deploy Fluentd
```hcl
job "logging-agent" {
  datacenters = ["saigon"]
  type        = "system"

  group "fluentd" {
    count = 1

    network {
      port "fluentd" {
        static = 24224
        to     = 24224
      }
      port "fluentd-health" {
        static = 24220
        to     = 24220
      }
    }

    volume "fluentd-data-log" {
      type   = "host"
      source = "fluent-data-log"
      read_only = false
    }

    task "fluentd" {
      driver = "docker"
      config {
        image   = "tuyendev/fluentd-els:1.15.1"
        command = "fluentd"
        args = [
          "-c",
          "/etc/fluend/fluend.conf"
        ]
        ports = ["fluentd", "fluentd-health"]
        volumes = [
          "local/fluend.conf:/etc/fluend/fluend.conf",
        ]
      }
      volume_mount {
        volume      = "fluentd-data-log"
        destination = "/fluentd/log"
      }
      template {
        data = <<EOH
<source>
  @type monitor_agent
  bind 0.0.0.0
  port 24220
</source>

<source>
  @type forward
  @label @ES
  port 24224
  bind 0.0.0.0
</source>
<label @ES>
  <match backend*.*>
    @type elasticsearch
    @log_level trace
    host {{ range $i, $s := service "elk-elasticsearch" }}{{.Address}}{{ if eq $i 0 }}{{end}}{{end}}
    port 9200
    type_name fluentd
    logstash_format true
    logstash_prefix backend_service_log
    time_key @timestamp
    include_timestamp true
    reconnect_on_error true
    reload_on_failure true
    reload_connections false
    request_timeout 120s
    <buffer>
      @type file
      path /fluentd/log/backend_service
      flush_thread_count "#{ENV['FLUENT_ELASTICSEARCH_BUFFER_FLUSH_THREAD_COUNT'] || '8'}"
      flush_interval "#{ENV['FLUENT_ELASTICSEARCH_BUFFER_FLUSH_INTERVAL'] || '5s'}"
      chunk_limit_size "#{ENV['FLUENT_ELASTICSEARCH_BUFFER_CHUNK_LIMIT_SIZE'] || '10KB'}"
      total_limit_size "#{ENV['FLUENT_ELASTICSEARCH_TOTAL_LIMIT_SIZE'] || '1MB'}"
      queue_limit_length "#{ENV['FLUENT_ELASTICSEARCH_BUFFER_QUEUE_LIMIT_LENGTH'] || '32'}"
      retry_max_interval "#{ENV['FLUENT_ELASTICSEARCH_BUFFER_RETRY_MAX_INTERVAL'] || '60s'}"
      retry_forever false
    </buffer>
  </match>
</label>
<label @ERROR>
  <match **>
    @type stdout
  </match>
</label>
EOH

        destination = "local/fluend.conf"
      }


      resources {
        cpu    = 1000
        memory = 1024
      }
      service {
        name = "fluentd-agent"
        port = "fluentd-health"
        check {
          name     = "alive"
          type     = "http"
          path     = "/api/plugins.json"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
```
