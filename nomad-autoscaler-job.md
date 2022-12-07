# Deploy Auto scaler Job

1. Detail job

```hcl
job "autoscaler" {
  type = "service"

  datacenters = ["saigon"]

  group "autoscaler" {
    count = 1

    network {
      port "http" {}
    }

    task "autoscaler" {
      driver = "docker"
      constraint {
        attribute = "${node.class}"
        operator  = "="
        value     = "monitor"
      }
      config {
        image   = "hashicorp/nomad-autoscaler:0.3.7"
        command = "nomad-autoscaler"
        ports   = ["http"]

        args = [
          "agent",
          "-config",
          "${NOMAD_TASK_DIR}/config.hcl",
          "-http-bind-address",
          "0.0.0.0",
          "-http-bind-port",
          "${NOMAD_PORT_http}",
        ]
      }

      template {
        data = <<EOF
nomad {
  address = "http://{{ range $i, $s := service "nomad" }}{{ if eq $i 0 }}{{.Address}}{{end}}{{end}}:4646"
  token = "845e4d5b-611e-66ca-30c6-f5e27a7fa092"
}

telemetry {
  prometheus_metrics = true
  disable_hostname   = true
}

apm "prometheus" {
  driver = "prometheus"
  config = {
    address = "http://{{ range $i, $s := service "prometheus" }}{{ if eq $i 0 }}{{.Address}}:{{.Port}}{{end}}{{end}}"
  }
}

strategy "target-value" {
  driver = "target-value"
}
EOF

        destination = "${NOMAD_TASK_DIR}/config.hcl"
      }

      resources {
        cpu    = 50
        memory = 128
      }

      service {
        name = "autoscaler"
        port = "http"

        check {
          type     = "http"
          path     = "/v1/health"
          interval = "3s"
          timeout  = "1s"
        }
      }
    }
  }
}
```
