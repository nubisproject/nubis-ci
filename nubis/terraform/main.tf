# Configure the AWS Provider
provider "aws" {
  region = "${var.region}"
}

module "ci-image" {
  source = "github.com/nubisproject/nubis-terraform//images?ref=v2.3.1"

  region        = "${var.region}"
  image_version = "${var.nubis_version}"
  project       = "nubis-ci"
}

# Create a new load balancer
resource "aws_elb" "ci" {
  count   = "${var.enabled}"
  name    = "ci-elb-${var.project}"
  subnets = ["${split(",", var.public_subnets)}"]

  internal = true

  listener {
    instance_port     = 8080
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 10
    target              = "HTTP:8080/jenkins/cc.xml"
    interval            = 30
  }

  cross_zone_load_balancing = true

  security_groups = [
    "${aws_security_group.elb.id}",
  ]

  tags = {
    Region           = "${var.region}"
    Arena            = "${var.arena}"
    TechnicalContact = "${var.technical_contact}"
  }
}

resource "aws_security_group" "elb" {
  count       = "${var.enabled}"
  name        = "ci-elb-${var.project}"
  description = "Allow inbound traffic for CI ${var.project}"

  vpc_id = "${var.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Region           = "${var.region}"
    Arena            = "${var.arena}"
    TechnicalContact = "${var.technical_contact}"
  }
}

resource "aws_security_group" "ci" {
  count       = "${var.enabled}"
  name        = "ci-${var.project}"
  description = "Allow inbound traffic for CI ${var.project}"

  vpc_id = "${var.vpc_id}"

  ingress {
    from_port = 8080
    to_port   = 8080
    protocol  = "tcp"

    security_groups = [
      "${aws_security_group.elb.id}",
      "${var.monitoring_security_group_id}",
      "${var.sso_security_group_id}",
    ]
  }

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    security_groups = [
      "${var.ssh_security_group_id}",
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Region           = "${var.region}"
    Arena            = "${var.arena}"
    TechnicalContact = "${var.technical_contact}"
  }
}

resource "aws_autoscaling_group" "ci" {
  count               = "${var.enabled}"
  vpc_zone_identifier = ["${split(",", var.private_subnets)}"]

  # This is on purpose, when the LC changes, will force creation of a new ASG
  name = "ci-${var.project} - ${aws_launch_configuration.ci.name}"

  load_balancers = [
    "${aws_elb.ci.name}",
  ]

  max_size                  = "2"
  min_size                  = "0"
  health_check_grace_period = 1800
  health_check_type         = "ELB"
  desired_capacity          = "1"
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.ci.name}"

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  tag {
    key                 = "Name"
    value               = "CI server for ${var.project} (${var.nubis_version})"
    propagate_at_launch = true
  }

  tag {
    key                 = "TechnicalContact"
    value               = "${var.technical_contact}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Arena"
    value               = "${var.arena}"
    propagate_at_launch = true
  }
}

resource "aws_launch_configuration" "ci" {
  count = "${var.enabled}"

  name_prefix = "ci-${var.project}-"

  image_id = "${module.ci-image.image_id}"

  instance_type = "${var.instance_type}"
  key_name      = "${var.key_name}"

  security_groups = [
    "${aws_security_group.ci.id}",
    "${var.internet_security_group_id}",
    "${var.shared_services_security_group_id}",
  ]

  iam_instance_profile = "${aws_iam_instance_profile.ci.name}"

  enable_monitoring = false

  root_block_device = {
    volume_size           = "${var.root_storage_size}"
    delete_on_termination = true
  }

  user_data = <<EOF
NUBIS_ACCOUNT=${var.account_name}
NUBIS_PROJECT=${var.project}
NUBIS_ARENA=${var.arena}
NUBIS_DOMAIN=${var.nubis_domain}
NUBIS_PROJECT_URL=https://sso.${var.arena}.${var.region}.${var.account_name}.${var.nubis_domain}/jenkins/
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
NUBIS_OPER_GROUPS="${var.nubis_oper_groups}"
NUBIS_USER_GROUPS="${var.nubis_user_groups}"
EOF
}

resource "aws_s3_bucket" "ci_artifacts" {
  count         = "${var.enabled}"
  bucket_prefix = "ci-${var.project}-artifacts-"

  acl = "private"

  force_destroy = true

  versioning {
    enabled = true
  }

  tags = {
    Region           = "${var.region}"
    Arena            = "${var.arena}"
    TechnicalContact = "${var.technical_contact}"
  }
}

resource "aws_iam_instance_profile" "ci" {
  count = "${var.enabled}"
  name  = "ci-${var.project}-${var.arena}-${var.region}"
  role  = "${aws_iam_role.ci.name}"
}

resource "aws_iam_role" "ci" {
  count = "${var.enabled}"
  name  = "ci-${var.project}-${var.arena}-${var.region}"
  path  = "/"

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
  count  = "${var.enabled}"
  name   = "ci-${var.project}-${var.arena}-${var.region}-artifacts"
  role   = "${aws_iam_role.ci.id}"
  policy = "${data.aws_iam_policy_document.ci_artifacts.json}"
}

data "aws_iam_policy_document" "ci_artifacts" {
  count = "${var.enabled}"

  statement {
    sid = "AllBuckets"

    actions = [
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid = "ListBucket"

    actions = [
      "s3:ListBucket",
    ]

    resources = [
      "${aws_s3_bucket.ci_artifacts.arn}",
    ]
  }

  statement {
    sid = "ActInBucket"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]

    resources = [
      "${aws_s3_bucket.ci_artifacts.arn}",
      "${aws_s3_bucket.ci_artifacts.arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "ci_build" {
  count  = "${var.enabled}"
  name   = "ci-${var.project}-${var.arena}-${var.region}-build"
  role   = "${aws_iam_role.ci.id}"
  policy = "${data.aws_iam_policy_document.ci_build.json}"
}

data "aws_iam_policy_document" "ci_build" {
  count = "${var.enabled}"

  statement {
    sid = "build"

    actions = [
      "iam:CreateServiceLinkedRole",
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
      "ec2:DescribeInstanceStatus",
      "ec2:CreateSnapshot",
      "ec2:DeleteSnapshot",
      "ec2:DescribeSnapshots",
      "ec2:DescribeImages",
      "ec2:RegisterImage",
      "ec2:DeregisterImage",
      "ec2:CreateTags",
      "ec2:ModifyImageAttribute",
      "ec2:DescribeRegions",
    ]

    resources = [
      "*",
    ]
  }
}

data "aws_iam_policy_document" "ci_deploy" {
  count = "${var.enabled}"

  statement {
    sid = "deploy"

    actions = [
      "autoscaling:AttachLoadBalancerTargetGroups",
      "autoscaling:DetachLoadBalancerTargetGroups",
      "autoscaling:AttachLoadBalancers",
      "autoscaling:DetachLoadBalancers",
      "autoscaling:DescribeLoadBalancers",
      "autoscaling:CreateAutoScalingGroup",
      "autoscaling:CreateLaunchConfiguration",
      "autoscaling:DeleteLaunchConfiguration",
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
      "autoscaling:SetInstanceHealth",
      "autoscaling:PutLifecycleHook",
      "autoscaling:DeleteLifecycleHook",
      "autoscaling:DescribeLifecycleHooks",
      "autoscaling:DescribeLifecycleHookTypes",
      "autoscaling:PutNotificationConfiguration",
      "autoscaling:DescribeNotificationConfigurations",
      "autoscaling:DescribeAutoScalingNotificationTypes",
      "autoscaling:DeleteNotificationConfiguration",
      "acm:AddTagsToCertificate",
      "acm:DeleteCertificate",
      "acm:DescribeCertificate",
      "acm:ExportCertificate",
      "acm:GetCertificate",
      "acm:ImportCertificate",
      "acm:ListCertificates",
      "acm:ListTagsForCertificate",
      "acm:RemoveTagsFromCertificate",
      "acm:RequestCertificate",
      "acm:ResendValidationEmail",
      "cloudfront:CreateCloudFrontOriginAccessIdentity",
      "cloudfront:CreateDistribution",
      "cloudfront:CreateDistributionWithTags",
      "cloudfront:CreateInvalidation",
      "cloudfront:CreateStreamingDistribution",
      "cloudfront:CreateStreamingDistributionWithTags",
      "cloudfront:DeleteCloudFrontOriginAccessIdentity",
      "cloudfront:DeleteDistribution",
      "cloudfront:DeleteStreamingDistribution",
      "cloudfront:GetCloudFrontOriginAccessIdentity",
      "cloudfront:GetCloudFrontOriginAccessIdentityConfig",
      "cloudfront:GetDistribution",
      "cloudfront:GetDistributionConfig",
      "cloudfront:GetInvalidation",
      "cloudfront:GetStreamingDistribution",
      "cloudfront:GetStreamingDistributionConfig",
      "cloudfront:ListCloudFrontOriginAccessIdentities",
      "cloudfront:ListDistributions",
      "cloudfront:ListDistributionsByWebACLId",
      "cloudfront:ListInvalidations",
      "cloudfront:ListStreamingDistributions",
      "cloudfront:ListTagsForResource",
      "cloudfront:TagResource",
      "cloudfront:UntagResource",
      "cloudfront:UpdateCloudFrontOriginAccessIdentity",
      "cloudfront:UpdateDistribution",
      "cloudfront:UpdateStreamingDistribution",
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
      "ec2:ReleaseAddresses",
      "ec2:DisassociateAddress",
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
      "elasticache:ListTagsForResource",
      "elasticache:RemoveTagsFromResource",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
      "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
      "elasticloadbalancing:CreateLoadBalancerPolicy",
      "elasticloadbalancing:DeleteLoadBalancerPolicy",
      "elasticloadbalancing:DescribeLoadBalancerPolicies",
      "elasticloadbalancing:DescribeLoadBalancerPolicyTypes",
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
      "rds:ListTagsForResource",
      "rds:RemoveTagsFromResource",
      "route53:GetHostedZone",
      "route53:ListHostedZones",
      "route53:GetHostedZone",
      "route53:GetChange",
      "route53:DeleteHostedZone",
      "route53:CreateHostedZone",
      "route53:CreateReusableDelegationSet",
      "route53:DeleteReusableDelegationSet",
      "route53:GetReusableDelegationSet",
      "route53:UpdateHostedZoneComment",
      "route53:ChangeTagsForResource",
      "route53:ListTagsForResource",
      "route53:ListResourceRecordSets",
      "route53:ChangeResourceRecordSets",
      "sns:CreateTopic",
      "sns:DeleteTopic",
      "sns:GetTopicAttributes",
      "sqs:CreateQueue",
      "sqs:DeleteQueue",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ListQueues",
      "sqs:ListQueueTags",
      "sqs:TagQueue",
      "sqs:UntagQueue",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:DescribeAlarms",
      "iam:PassRole",
      "iam:GetRole",
      "iam:CreateUser",
      "iam:CreateRole",
      "iam:CreateAccessKey",
      "iam:PutUserPolicy",
      "iam:ListAccessKeys",
      "iam:ListGroupsForUser",
      "iam:DeleteUserPolicy",
      "iam:DeleteAccessKey",
      "iam:DeleteRolePermissionsBoundary",
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
      "iam:DeleteInstanceProfile",
      "iam:ListInstanceProfilesForRole",
      "s3:*",
      "lambda:InvokeFunction",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid = "DNS"

    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
    ]

    resources = [
      "arn:aws:route53:::hostedzone/${var.zone_id}",
    ]
  }
}

resource "aws_iam_role_policy" "ci_deploy" {
  count  = "${var.enabled}"
  name   = "ci-${var.project}-${var.arena}-${var.region}-deploy"
  role   = "${aws_iam_role.ci.id}"
  policy = "${data.aws_iam_policy_document.ci_deploy.json}"
}

# This null resource is responsible for publishing secrets to Unicreds
resource "null_resource" "unicreds" {
  count = "${var.enabled}"

  lifecycle {
    create_before_destroy = true
  }

  # Important to list here every variable that affects what needs to be put into unicreds
  triggers {
    slack_token      = "${var.slack_token}"
    region           = "${var.region}"
    consul_acl_token = "${var.consul_acl_token}"
    context          = "-E region:${var.region} -E arena:${var.arena} -E service:${var.project}"
    unicreds         = "unicreds -r ${var.region} put -k ${var.credstash_key} ${var.project}/${var.arena}/ci"
    unicreds_rm      = "unicreds -r ${var.region} delete -k ${var.credstash_key} ${var.project}/${var.arena}/ci"
    version          = "${var.nubis_version}"
    newrelic_api_key = "${var.newrelic_api_key}"
  }

  provisioner "local-exec" {
    command = "${self.triggers.unicreds}/slack_token ${var.slack_token} ${self.triggers.context}"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "${self.triggers.unicreds_rm}/slack_token"
  }

  provisioner "local-exec" {
    command = "${self.triggers.unicreds}/newrelic_api_key ${var.newrelic_api_key} ${self.triggers.context}"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "${self.triggers.unicreds_rm}/newrelic_api_key"
  }

  provisioner "local-exec" {
    command = "${self.triggers.unicreds}/consul_acl_token ${var.consul_acl_token} ${self.triggers.context}"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "${self.triggers.unicreds_rm}/consul_acl_token"
  }
}
