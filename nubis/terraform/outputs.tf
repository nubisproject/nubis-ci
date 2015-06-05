output "elb" {
    value = "http://ci.${var.domain}/"
}


# Configure the Consul provider
provider "consul" {
    address = "ui.${var.region}.consul.${var.environment}.${var.nubis_domain}:80" 
    datacenter = "${var.region}"
    scheme = "http"
}

resource "consul_keys" "jenkins" {
  key {
        name = "url"
        path = "environments/${var.environment}/global/ci/${var.project}"
        value = "http://ci.${var.domain}/"
    }
}

