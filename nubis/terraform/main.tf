# Configure the AWS Provider
provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.region}"
}

# Create a new load balancer
resource "aws_elb" "jenkins" {
  name = "jenkins-elb-${var.project}-${var.release}-${var.build}"
  subnets = [ "${var.elb_subnet_id}" ]

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

  security_groups = [
    "${aws_security_group.elb.id}"
  ]
}

# Create a web server
resource "aws_instance" "jenkins" {
    ami = "${var.ami}"
    subnet_id = "${var.subnet_id}"

    tags {
        Name = "Nubis Jenkins ${var.project} (${var.release}.${var.build})"
    }
    
    key_name = "${var.key_name}"
    
    instance_type = "m3.medium"
    
    iam_instance_profile = "${var.iam_instance_profile}"
    
    security_groups = [
      "${aws_security_group.jenkins.id}"
    ]
    
    user_data = "NUBIS_PROJECT=${var.project}\nNUBIS_ENVIRONMENT=${var.environment}\nCONSUL_PUBLIC=1\nCONSUL_DC=${var.region}\nCONSUL_SECRET=${var.consul_secret}\nCONSUL_JOIN=${var.consul}\nCONSUL_KEY=\"${file("${var.consul_ssl_key}")}\"\nCONSUL_CERT=\"${file("${var.consul_ssl_cert}")}\"\nNUBIS_CI_NAME=${var.project}\nNUBIS_GIT_REPO=${var.git_repo}\nNUBIS_CI_PASSWORD=${var.admin_password}\nNUBIS_CI_BUCKET=${var.s3_bucket_name}\nNUBIS_CI_BUCKET_REGION=${var.region}\nNUBIS_CI_BUCKET_PROFILE=${var.iam_instance_profile}"
}

resource "aws_security_group" "elb" {
  name = "elb-${var.project}.${var.release}.${var.build}"
  description = "Allow inbound traffic for Jenkins"

  vpc_id = "${var.vpc_id}"

  ingress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "jenkins" {
  name = "jenkins-${var.project}.${var.release}.${var.build}"
  description = "Allow inbound traffic for Jenkins"

  vpc_id = "${var.vpc_id}"

  ingress {
      from_port = 0
      to_port = 8080
      protocol = "tcp"
      security_groups = [
       "${aws_security_group.elb.id}"
      ]
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

resource "aws_route53_record" "jenkins" {
   zone_id = "${var.zone_id}"
   name = "ci"
   type = "CNAME"
   ttl = "30"
   records = ["dualstack.${aws_elb.jenkins.dns_name}"]
}
