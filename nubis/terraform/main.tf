# Configure the AWS Provider
provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.region}"
}

# Create a new load balancer
resource "aws_elb" "ci" {
  name = "ci-elb-${var.project}-${var.release}-${var.build}"
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
    interval = 5
  }

  cross_zone_load_balancing = true

  security_groups = [
    "${aws_security_group.elb.id}"
  ]

}

resource "aws_security_group" "elb" {
  name = "ci-elb-${var.project}.${var.release}.${var.build}"
  description = "Allow inbound traffic for CI"

  vpc_id = "${var.vpc_id}"

  ingress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ci" {
  name = "ci-${var.project}.${var.release}.${var.build}"
  description = "Allow inbound traffic for CI"

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

resource "aws_autoscaling_group" "ci" {
  availability_zones = [ ]
  vpc_zone_identifier = [ "subnet-a9139ccc", "subnet-cb3a97bc", "subnet-227fbc7b" ]

  name = "ci-${var.project}-${var.release}-${var.build}"
  
  load_balancers = [
   "${aws_elb.ci.name}"
  ]

  max_size = "2"
  min_size = "0"
  health_check_grace_period = 300
  health_check_type = "ELB"
  desired_capacity = "1"
  force_delete = true
  launch_configuration = "${aws_launch_configuration.ci.name}"

  tag {
    key = "Name"
    value = "CI server for ${var.project} (v/${var.release}.${var.build})"
    propagate_at_launch = true
  }

}

resource "aws_launch_configuration" "ci" {
    name = "ci-${var.project}-${var.release}-${var.build}"
    image_id = "${var.ami}"
    instance_type = "m3.medium"
    key_name = "${var.key_name}"
    security_groups = [
      "${aws_security_group.ci.id}",
      "${var.internet_security_group_id}",
      "${var.shared_services_security_group_id}",
    ]
    
    
    
    iam_instance_profile = "${var.iam_instance_profile}"

    user_data = "NUBIS_PROJECT=${var.project}\nNUBIS_ENVIRONMENT=${var.environment}\nNUBIS_DOMAIN=${var.nubis_domain}\nNUBIS_PROJECT_URL=http://${aws_route53_record.ci.name}/\nNUBIS_CI_NAME=${var.project}\nNUBIS_GIT_REPO=${var.git_repo}\nNUBIS_CI_PASSWORD=${var.admin_password}\nNUBIS_CI_BUCKET=${var.s3_bucket_name}\nNUBIS_CI_BUCKET_REGION=${var.region}\n"

    depends_on = ["aws_route53_record.ci"]
}

resource "aws_route53_record" "ci" {
   zone_id = "${var.zone_id}"
   name = "ci.${var.domain}"
   type = "CNAME"
   ttl = "30"
   records = ["dualstack.${aws_elb.ci.dns_name}"]
}
