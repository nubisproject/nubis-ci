# Configure the Consul provider
provider "consul" {
    address = "${var.consul}:8500"
    datacenter = "${var.region}"
}

resource "consul_keys" "app" {
    # Read the launch AMI from Consul
    key {
        name = "ami"
        path = "nubis/${var.project}/releases/${var.release}.${var.build}/${var.region}"
    }
}

# Consul outputs
resource "consul_keys" "jenkins" {
    datacenter = "${var.region}"
   
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

# Configure the AWS Provider
provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.region}"
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
    target = "HTTP:8080/cc.xml"
    interval = 30
  }

  instances = ["${aws_instance.jenkins.id}"]
  cross_zone_load_balancing = true
}

# Create a web server
resource "aws_instance" "jenkins" {
    ami = "${consul_keys.app.var.ami}"
    
    tags {
        Name = "Gozer Jenkins Test"
    }
    
    key_name = "${var.key_name}"
    
    instance_type = "m3.medium"
    
    security_groups = [
      "${aws_security_group.jenkins.name}"
    ]
    
    user_data = "CONSUL_PUBLIC=1\nCONSUL_DC=${var.region}\nCONSUL_SECRET=${var.secret}\nCONSUL_JOIN=${var.consul}"
}

resource "aws_security_group" "jenkins" {
  name = "jenkins"
  description = "Allow inbound traffic for Jenkins"

  ingress {
      from_port = 0
      to_port = 8080
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
      from_port = 0
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
}
