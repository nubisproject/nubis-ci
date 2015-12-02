# Configure the AWS Provider
provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.region}"
}

# Create a new load balancer
resource "aws_elb" "ci" {
  name = "ci-elb-${var.project}"
  subnets = ["${split(",", var.public_subnets)}"]

  listener {
    instance_port = 8080
    instance_protocol = "http"
    lb_port = 443
    lb_protocol = "https"
    ssl_certificate_id = "${var.https_cert_arn}"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 10
    target = "HTTP:8080/cc.xml"
    interval = 30 
  }

  cross_zone_load_balancing = true

  security_groups = [
    "${aws_security_group.elb.id}"
  ]

}

resource "aws_security_group" "elb" {
  name = "ci-elb-${var.project}"
  description = "Allow inbound traffic for CI ${var.project}"

  vpc_id = "${var.vpc_id}"

  ingress {
      from_port = 443
      to_port = 443
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_security_group" "ci" {
  name = "ci-${var.project}"
  description = "Allow inbound traffic for CI ${var.project}"

  vpc_id = "${var.vpc_id}"

  ingress {
      from_port = 8080
      to_port = 8080
      protocol = "tcp"
      security_groups = [
       "${aws_security_group.elb.id}"
      ]
  }
  
  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      security_groups = [
        "${var.ssh_security_group_id}"
      ]
  }

  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_autoscaling_group" "ci" {
  lifecycle { create_before_destroy = true }
  vpc_zone_identifier = ["${split(",", var.private_subnets)}"]

  name = "ci-${var.project}"
  
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
    image_id = "${var.ami}"
    instance_type = "m3.medium"
    key_name = "${var.key_name}"
    security_groups = [
      "${aws_security_group.ci.id}",
      "${var.internet_security_group_id}",
      "${var.shared_services_security_group_id}",
    ]
    lifecycle { create_before_destroy = true }
    iam_instance_profile = "${aws_iam_instance_profile.ci.name}"

    user_data = <<EOF
NUBIS_ACCOUNT=${var.account_name}
NUBIS_PROJECT=${var.project}
NUBIS_ENVIRONMENT=${var.environment}
NUBIS_DOMAIN=${var.nubis_domain}
NUBIS_PROJECT_URL=http://${aws_route53_record.ci.fqdn}/
NUBIS_CI_NAME=${var.project}
NUBIS_GIT_REPO=${var.git_repo}
NUBIS_CI_BUCKET=${aws_s3_bucket.ci_artifacts.id}
NUBIS_CI_BUCKET_REGION=${var.region}
NUBIS_CI_EMAIL=${var.email}
NUBIS_CI_GITHUB_ADMINS=${var.admins}
NUBIS_CI_GITHUB_ORGANIZATIONS=${var.organizations}
NUBIS_CI_GITHUB_CLIENT_TOKEN=${var.github_oauth_client_id}
NUBIS_CI_GITHUB_CLIENT_SECRET=${var.github_oauth_client_secret}
EOF

    depends_on = ["aws_route53_record.ci"]
}

resource "aws_route53_record" "ci" {
   zone_id = "${var.zone_id}"
   name = "ci.${var.project}.${var.environment}"
   type = "CNAME"
   ttl = "30"
   records = ["dualstack.${aws_elb.ci.dns_name}"]
}

resource "aws_s3_bucket" "ci_artifacts" {
    lifecycle { create_before_destroy = true }
    bucket = "${var.s3_bucket_name}"
    acl = "private"

    tags = {
        Region = "${var.region}"
        Environment = "${var.environment}"
    }
}

resource "aws_iam_instance_profile" "ci" {
    name = "ci-${var.project}-${var.environment}-${var.region}"
    roles = [
      "${aws_iam_role.ci.name}",
    ]
}

resource "aws_iam_role" "ci" {
    name = "ci-${var.project}-${var.environment}-${var.region}"
    path = "/"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ci_artifacts" {
    name    = "ci-${var.project}-${var.environment}-${var.region}-artifacts"
    role    = "${aws_iam_role.ci.id}"
    policy  = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [ "arn:aws:s3:::${aws_s3_bucket.ci_artifacts.id}" ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": [ "arn:aws:s3:::${aws_s3_bucket.ci_artifacts.id}/*" ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "ci_build" {
    name    = "ci-${var.project}-${var.environment}-${var.region}-build"
    role    = "${aws_iam_role.ci.id}"
    policy  = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
              "Effect": "Allow",
              "Action": [
                "iam:PassRole",
                "ec2:CopyImage",
                "ec2:AttachVolume",
                "ec2:CreateVolume",
                "ec2:DeleteVolume",
                "ec2:CreateKeypair",
                "ec2:DeleteKeypair",
                "ec2:CreateSecurityGroup",
                "ec2:DeleteSecurityGroup",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:CreateImage",
                "ec2:RunInstances",
                "ec2:TerminateInstances",
                "ec2:StopInstances",
                "ec2:DescribeVolumes",
                "ec2:DetachVolume",
                "ec2:DescribeInstances",
                "ec2:CreateSnapshot",
                "ec2:DeleteSnapshot",
                "ec2:DescribeSnapshots",
                "ec2:DescribeImages",
                "ec2:RegisterImage",
                "ec2:CreateTags",
                "ec2:ModifyImageAttribute"
              ],
              "Resource": "*"
            }
    ]
}
EOF
}

resource "aws_iam_role_policy" "ci_deploy" {
    name    = "ci-${var.project}-${var.environment}-${var.region}-deploy"
    role    = "${aws_iam_role.ci.id}"
    policy  = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
              "Effect": "Allow",
              "Action": [
                "autoscaling:CreateAutoScalingGroup",
                "autoscaling:CreateLaunchConfiguration",
                "autoscaling:DeleteLaunchConfiguration",
                "autoscaling:DescribeAutoScalingGroup",
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:UpdateAutoScalingGroup",
                "autoscaling:DescribeScalingActivities",
                "autoscaling:DeleteAutoScalingGroup",
                "autoscaling:DescribeScheduledActions",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:PutScalingPolicy",
                "autoscaling:CreateOrUpdateTags",
                "autoscaling:DescribeAutoScalingInstances",
                "cloudformation:*",
                "ec2:createTags",
                "ec2:CreateSecurityGroup",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInstances",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeAccountAttributes",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:DeleteSecurityGroup",
                "ec2:allocateAddress",
                "ec2:describeAddresses",
                "elasticache:CreateCacheSubnetGroup",
                "elasticache:DeleteCacheSubnetGroup",
                "elasticache:DescribeCacheSubnetGroups",
                "elasticache:CreateCacheCluster",
                "elasticache:DescribeCacheClusters",
                "elasticache:DeleteCacheCluster",
                "elasticloadbalancing:ConfigureHealthCheck",
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
                "elasticloadbalancing:DeleteLoadBalancerListeners",
                "elasticloadbalancing:CreateLoadBalancerListeners",
                "rds:CreateDBInstance",
                "rds:CreateDBSubnetGroup",
                "rds:DeleteDBSubnetGroup",
                "rds:DescribeDBSubnetGroups",
                "rds:DeleteDBInstance",
                "rds:DescribeDBInstances",
                "rds:ModifyDBInstance",
                "rds:CreateDBInstanceReadReplica",
                "route53:GetChange",
                "route53:ListHostedZones",
                "route53:GetHostedZone",
                "cloudwatch:PutMetricAlarm",
                "iam:CreateUser",
                "iam:CreateRole",
                "iam:CreateAccessKey",
                "iam:PutUserPolicy",
                "iam:ListAccessKeys",
                "iam:DeleteUserPolicy",
                "iam:DeleteAccessKey",
                "iam:CreateInstanceProfile",
                "iam:AddRoleToInstanceProfile",
                "iam:PutRolePolicy",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:DeleteRole",
                "iam:DeleteUser",
                "iam:DeleteRolePolicy",
                "s3:*",
                "lambda:InvokeFunction"
              ],
              "Resource": "*"
            },
            {
              "Effect": "Allow",
              "Action": [
                "route53:ChangeResourceRecordSets",
                "route53:ListResourceRecordSets"
              ],
              "Resource": "arn:aws:route53:::hostedzone/${var.zone_id}"
            }
    ]
}
EOF
}
