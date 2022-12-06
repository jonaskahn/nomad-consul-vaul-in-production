# DEPLOY LOG MONITOR

### Deploy FluentD

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

    task "fluentd" {
      driver = "docker"
      config {
        image   = "fluent/fluentd:v1.15-1"
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

      template {
        data = <<EOH
<source>
  @type monitor_agent
  bind 0.0.0.0
  port 24220
</source>
<source>
  @type forward
  port 24224
  bind 0.0.0.0
</source>

<match *.*>
  @type stdout
</match>
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