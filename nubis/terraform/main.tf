# Configure the AWS Provider
provider "aws" {
    region = "${var.region}"
}

module "ci-image" {
  source = "github.com/nubisproject/nubis-deploy///modules/images?ref=master"

  region  = "${var.region}"
  version = "${var.version}"
  project = "nubis-ci"
}

resource "tls_private_key" "ci" {
  count = "${var.enabled}"
  lifecycle { create_before_destroy = true }

  algorithm = "RSA"
}

resource "tls_self_signed_cert" "ci" {
    count = "${var.enabled}"
    lifecycle { create_before_destroy = true }
    key_algorithm = "${tls_private_key.ci.algorithm}"
    private_key_pem = "${tls_private_key.ci.private_key_pem}"

    # Certificate expires after 1 year
    validity_period_hours = 4380

    # Generate a new certificate if Terraform is run within 30 days
    # of the certificate's expiration time.
    early_renewal_hours = 1020

    # Reasonable set of uses for a server SSL certificate.
    allowed_uses = [
        "key_encipherment",
        "digital_signature",
        "server_auth",
    ]

    subject {
        common_name = "ci.${var.project}.${var.environment}.${var.region}.${var.account_name}.${var.nubis_domain}"
        organization = "Mozilla Nubis"
    }
}

resource "aws_iam_server_certificate" "ci" {
    count = "${var.enabled}"
    lifecycle { create_before_destroy = true }

    name_prefix = "ci-${var.project}-"

    certificate_body = "${tls_self_signed_cert.ci.cert_pem}"
    private_key = "${tls_private_key.ci.private_key_pem}"

    provisioner "local-exec" {
      command = "sleep 30"
    }
}


# Create a new load balancer
resource "aws_elb" "ci" {
  count = "${var.enabled}"
  name = "ci-elb-${var.project}"
  subnets = ["${split(",", var.public_subnets)}"]

  listener {
    instance_port = 8080
    instance_protocol = "http"
    lb_port = 443
    lb_protocol = "https"
    ssl_certificate_id = "${aws_iam_server_certificate.ci.arn}"
  }

  health_check {
    healthy_threshold = 3
    unhealthy_threshold = 3
    timeout = 10
    target = "HTTP:8080/jenkins/cc.xml"
    interval = 30 
  }

  cross_zone_load_balancing = true

  security_groups = [
    "${aws_security_group.elb.id}"
  ]
    
  tags = {
    Region = "${var.region}"
    Environment = "${var.environment}"
    TechnicalContact = "${var.technical_contact}"
  }
}

resource "aws_security_group" "elb" {
  count = "${var.enabled}"
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

  tags = {
    Region = "${var.region}"
    Environment = "${var.environment}"
    TechnicalContact = "${var.technical_contact}"
  }
}

resource "aws_security_group" "ci" {
  count = "${var.enabled}"
  name = "ci-${var.project}"
  description = "Allow inbound traffic for CI ${var.project}"

  vpc_id = "${var.vpc_id}"

  ingress {
      from_port = 8080
      to_port = 8080
      protocol = "tcp"
      security_groups = [
       "${aws_security_group.elb.id}",
       "${var.monitoring_security_group_id}",
       "${var.sso_security_group_id}",
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

  tags = {
    Region = "${var.region}"
    Environment = "${var.environment}"
    TechnicalContact = "${var.technical_contact}"
  }
}

resource "aws_autoscaling_group" "ci" {
  count = "${var.enabled}"
  vpc_zone_identifier = ["${split(",", var.private_subnets)}"]

  # This is on purpose, when the LC changes, will force creation of a new ASG
  name = "ci-${var.project} - ${aws_launch_configuration.ci.name}"
  
  load_balancers = [
   "${aws_elb.ci.name}"
  ]

  max_size = "2"
  min_size = "0"
  health_check_grace_period = 600
  health_check_type = "ELB"
  desired_capacity = "1"
  force_delete = true
  launch_configuration = "${aws_launch_configuration.ci.name}"

  tag {
    key = "Name"
    value = "CI server for ${var.project} (${var.version})"
    propagate_at_launch = true
  }
  tag {
    key = "TechnicalContact"
    value = "${var.technical_contact}"
    propagate_at_launch = true
  }

}

resource "aws_launch_configuration" "ci" {
  count = "${var.enabled}"

  name_prefix = "ci-${var.project}-"

  image_id = "${module.ci-image.image_id}"

    instance_type = "t2.micro"
    key_name = "${var.key_name}"
    security_groups = [
      "${aws_security_group.ci.id}",
      "${var.internet_security_group_id}",
      "${var.shared_services_security_group_id}",
    ]
    iam_instance_profile = "${aws_iam_instance_profile.ci.name}"

    enable_monitoring = false

    user_data = <<EOF
NUBIS_ACCOUNT=${var.account_name}
NUBIS_PROJECT=${var.project}
NUBIS_ENVIRONMENT=${var.environment}
NUBIS_DOMAIN=${var.nubis_domain}
NUBIS_PROJECT_URL=https://${aws_route53_record.ci.fqdn}/
NUBIS_CI_NAME=${var.project}
NUBIS_GIT_REPO=${var.git_repo}
NUBIS_GIT_BRANCHES="${var.git_branches}"
NUBIS_CI_BUCKET=${aws_s3_bucket.ci_artifacts.id}
NUBIS_CI_BUCKET_REGION=${var.region}
NUBIS_CI_EMAIL=${var.email}
NUBIS_CI_GITHUB_ADMINS=${var.admins}
NUBIS_CI_GITHUB_ORGANIZATIONS=${var.organizations}
NUBIS_CI_SLACK_CHANNEL="${var.slack_channel}"
NUBIS_CI_SLACK_DOMAIN="${var.slack_domain}"
NUBIS_SUDO_GROUPS="${var.nubis_sudo_groups}"
NUBIS_USER_GROUPS="${var.nubis_user_groups}"
EOF

}

resource "aws_route53_record" "ci" {
  count = "${var.enabled}"
  zone_id = "${var.zone_id}"
  name = "ci.${var.project}.${var.environment}"
  type = "CNAME"
  ttl = "30"
  records = ["dualstack.${aws_elb.ci.dns_name}"]
}

resource "aws_s3_bucket" "ci_artifacts" {
  count = "${var.enabled}"
    bucket = "${var.s3_bucket_name}"

    acl = "private"

    force_destroy = true

    versioning {
      enabled = true
    }

    tags = {
        Region = "${var.region}"
        Environment = "${var.environment}"
        TechnicalContact = "${var.technical_contact}"
    }
}

resource "aws_iam_instance_profile" "ci" {
  count = "${var.enabled}"
    name = "ci-${var.project}-${var.environment}-${var.region}"
    roles = [
      "${aws_iam_role.ci.name}",
    ]
}

resource "aws_iam_role" "ci" {
  count = "${var.enabled}"
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
  count = "${var.enabled}"
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
            "Resource": [ "${aws_s3_bucket.ci_artifacts.arn}" ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:ListObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": [ "${aws_s3_bucket.ci_artifacts.arn}/*" ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "ci_build" {
  count = "${var.enabled}"
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
                "ec2:DescribeSpotPriceHistory",
                "ec2:RequestSpotInstances",
                "ec2:CancelSpotInstanceRequests",
                "ec2:DescribeSpotInstanceRequests",
                "ec2:CopyImage",
                "ec2:AttachVolume",
                "ec2:CreateVolume",
                "ec2:DeleteVolume",
                "ec2:CreateKeypair",
                "ec2:DeleteKeypair",
                "ec2:DescribeKeyPairs",
                "ec2:CreateSecurityGroup",
                "ec2:DeleteSecurityGroup",
                "ec2:RevokeSecurityGroupEgress",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:AuthorizeSecurityGroupEgress",
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
                "ec2:DeregisterImage",
                "ec2:CreateTags",
                "ec2:ModifyImageAttribute",
                "ec2:DescribeRegions"
              ],
              "Resource": "*"
            }
    ]
}
EOF
}

resource "aws_iam_role_policy" "ci_deploy" {
  count = "${var.enabled}"
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
                "autoscaling:DescribePolicies",
                "autoscaling:DeletePolicy",
                "autoscaling:UpdateAutoScalingGroup",
                "autoscaling:DescribeScalingActivities",
                "autoscaling:DeleteAutoScalingGroup",
                "autoscaling:DescribeScheduledActions",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:PutScalingPolicy",
                "autoscaling:CreateOrUpdateTags",
                "autoscaling:DeleteTags",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:EnableMetricsCollection",
                "ec2:createTags",
                "ec2:deleteTags",
                "ec2:CreateSecurityGroup",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInstances",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeAccountAttributes",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:AuthorizeSecurityGroupEgress",
                "ec2:RevokeSecurityGroupEgress",
                "ec2:DeleteSecurityGroup",
                "ec2:allocateAddress",
                "ec2:describeAddresses",
                "ec2:DescribeSubnets",
                "ec2:DescribeNetworkInterfaces",
                "ec2:CreateNetworkInterface",
                "ec2:DeleteNetworkInterface",
                "ec2:DescribeNetworkInterfaceAttribute",
                "ec2:ModifyNetworkInterfaceAttribute",
                "elasticache:CreateCacheSubnetGroup",
                "elasticache:DeleteCacheSubnetGroup",
                "elasticache:DescribeCacheSubnetGroups",
                "elasticache:CreateCacheCluster",
                "elasticache:DescribeCacheClusters",
                "elasticache:DeleteCacheCluster",
                "elasticache:AddTagsToResource",
                "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
                "elasticloadbalancing:ConfigureHealthCheck",
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
                "elasticloadbalancing:DeleteLoadBalancerListeners",
                "elasticloadbalancing:CreateLoadBalancerListeners",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:DescribeTags",
                "elasticloadbalancing:AttachLoadBalancerToSubnets",
                "elasticloadbalancing:DescribeInstanceHealth",
                "elasticfilesystem:CreateFileSystem",
                "elasticfilesystem:DescribeFileSystems",
                "elasticfilesystem:DeleteFileSystem",
                "elasticfilesystem:CreateMountTarget",
                "elasticfilesystem:DescribeMountTargets",
                "elasticfilesystem:DescribeMountTargetSecurityGroups",
                "elasticfilesystem:ModifyMountTargetSecurityGroups",
                "elasticfilesystem:DeleteMountTarget",
                "elasticfilesystem:CreateTags",
                "elasticfilesystem:DescribeTags",
                "elasticfilesystem:DeleteTags",
                "rds:CreateDBInstance",
                "rds:CreateDBSubnetGroup",
                "rds:DeleteDBSubnetGroup",
                "rds:DescribeDBSubnetGroups",
                "rds:DeleteDBInstance",
                "rds:DescribeDBInstances",
                "rds:ModifyDBInstance",
                "rds:CreateDBInstanceReadReplica",
                "rds:CreateDBParameterGroup",
                "rds:DeleteDBParameterGroup",
                "rds:DescribeDBParameterGroups",
                "rds:DescribeDBParameters",
                "rds:ModifyDBParameterGroup",
                "rds:ResetDBParameterGroup",
                "rds:AddTagsToResource",
                "route53:GetChange",
                "route53:ListHostedZones",
                "route53:GetHostedZone",
                "cloudwatch:PutMetricAlarm",
                "cloudwatch:DeleteAlarms",
                "cloudwatch:DescribeAlarms",
                "iam:GetRole",
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
                "iam:GetInstanceProfile",
                "iam:GetUser",
                "iam:GetRolePolicy",
                "iam:GetUserPolicy",
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

# This null resource is responsible for publishing secrets to Unicreds
resource "null_resource" "unicreds" {
  count = "${var.enabled}"

  lifecycle {
    create_before_destroy = true
  }

  # Important to list here every variable that affects what needs to be put into credstash
  triggers {
    github_oauth_client_id = "${var.github_oauth_client_id}"
    github_oauth_client_secret = "${var.github_oauth_client_secret}"
    slack_token      = "${var.slack_token}"
    region           = "${var.region}"
    context          = "-E region:${var.region} -E environment:${var.environment} -E service:${var.project}"
    unicreds         = "unicreds -r ${var.region} put -k ${var.credstash_key} ${var.project}/${var.environment}/ci"
    version          = "${var.version}"
  }

  provisioner "local-exec" {
    command = "${self.triggers.unicreds}/github_oauth_client_id ${var.github_oauth_client_id} ${self.triggers.context}"
  }

  provisioner "local-exec" {
    command = "${self.triggers.unicreds}/github_oauth_client_secret ${var.github_oauth_client_secret} ${self.triggers.context}"
  }

  provisioner "local-exec" {
    command = "${self.triggers.unicreds}/slack_token ${var.slack_token} ${self.triggers.context}"
  }
}
