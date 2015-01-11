variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_region" {
    default = "us-east-1"
}

variable "amis" {
  default = {
    us-east-1 = "ami-eafa8a82"
    us-west-2 = "ami-ad603c9d"
  }
}

# Configure the Consul provider
provider "consul" {
    address = "consul.service.consul:8500"
    datacenter = "phx1"
}

# Consul outputs
resource "consul_keys" "jenkins" {
    datacenter = "phx1"
   
    # Set the CNAME of our load balancer as a key
    key {
        name = "elb_cname"
        path = "aws/jenkins/url"
        value = "http://${aws_elb.jenkins.dns_name}/"
    }
    
    key {
    	name = "instance-id"
	path = "aws/jenkins/instance-id"
	value = "${aws_instance.jenkins.id}"
    }
}

# Consul inputs (example)
resource "consul_keys" "ssh" {
    datacenter = "phx1"
    
    key {
         name = "key"
	 path = "aws/jenkins/key"
    }
}

# Configure the AWS Provider
provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.aws_region}"
}

# Create a new load balancer
resource "aws_elb" "jenkins" {
  name = "jenkins-elb"
  availability_zones = ["us-east-1b", "us-east-1c", "us-east-1d", "us-east-1e" ]

  listener {
    instance_port = 8080
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "HTTP:8080/"
    interval = 30
  }

  instances = ["${aws_instance.jenkins.id}"]
  cross_zone_load_balancing = true
}

# Create a web server
resource "aws_instance" "jenkins" {
    ami = "${lookup(var.amis, var.aws_region)}"
    
    tags {
        Name = "Gozer Jenkins Test"
    }
    
    key_name = "${consul_keys.ssh.var.key}"
    instance_type = "m3.medium"
    
    security_groups = [
      "${aws_security_group.jenkins.name}"
    ]
    
    user_data = "{ consul => 'consul://token@1.2.3.4:8500' }"
}

resource "aws_security_group" "jenkins" {
  name = "jenkins"
  description = "Allow inbound traffic for Jenkins"

  ingress {
      from_port = 0
      to_port = 8080
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      #security_groups = [
      #    "amazon-elb/sg-843f59ed"
      #]
  }
  
  ingress {
      from_port = 0
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
}

output "url" {
    value = "http://${aws_elb.jenkins.dns_name}/"
}

