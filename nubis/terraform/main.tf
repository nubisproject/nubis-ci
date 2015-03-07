# Configure the AWS Provider
provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.region}"
}

# Create a new load balancer
resource "aws_elb" "jenkins" {
  name = "jenkins-elb-${var.project}-${var.release}-${var.build}"
  availability_zones = ["us-east-1b", "us-east-1c", "us-east-1d","us-east-1e" ]

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
    ami = "ami-a68cd6ce"

    tags {
        Name = "Nubis Jenkins ${var.project} (${var.release}.${var.build})"
    }
    
    key_name = "${var.key_name}"
    
    instance_type = "m3.medium"
    
    iam_instance_profile = "${var.iam_instance_profile}"
    
    security_groups = [
      "${aws_security_group.jenkins.name}"
    ]
    
    user_data = "NUBIS_PROJECT=${var.project}\nNUBIS_ENVIRONMENT=${var.environment}\nCONSUL_PUBLIC=1\nCONSUL_DC=${var.region}\nCONSUL_SECRET=${var.consul_secret}\nCONSUL_JOIN=${var.consul}\nCONSUL_KEY=\"${file("${var.consul_ssl_key}")}\"\nCONSUL_CERT=\"${file("${var.consul_ssl_cert}")}\"\nNUBIS_CI_NAME=${var.project}\nNUBIS_GIT_REPO=${var.git_repo}\nNUBIS_admin_password=${var.admin_password}"
}

resource "aws_security_group" "jenkins" {
  name = "jenkins-${var.project}.${var.release}.${var.build}"
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
  
  // This is for the consul gossip traffic
  ingress {
    from_port = 8300
    to_port = 8303
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // This is for the consul gossip traffic
  ingress {
    from_port = 8300
    to_port = 8303
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
