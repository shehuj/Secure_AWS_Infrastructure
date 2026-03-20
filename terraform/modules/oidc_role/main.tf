terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}


# GitHub OIDC Provider - create if it doesn't exist
# This resource creates the OIDC provider unconditionally
# If it already exists in your AWS account, import it with:
# terraform import module.oidc_role.aws_iam_openid_connect_provider.github[0] arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]

  tags = {
    Name      = "GitHub-OIDC-Provider"
    ManagedBy = "Terraform"
  }
}

# Data source to get existing OIDC provider (if not creating)
data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume.json

  tags = {
    Name        = var.role_name
    ManagedBy   = "Terraform"
    Environment = var.environment
    GitHubRepo  = var.repo
  }
}

# Assume Role Policy Document
data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.github_repositories
    }
  }
}

# ── Policy 1: Compute & Networking ───────────────────────────────────────────
data "aws_iam_policy_document" "terraform_compute" {
  statement {
    sid    = "EC2VPCNetwork"
    effect = "Allow"
    actions = [
      "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:DescribeVpcs",
      "ec2:ModifyVpcAttribute", "ec2:DescribeVpcAttribute",
      "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:DescribeSubnets", "ec2:ModifySubnetAttribute",
      "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway",
      "ec2:AttachInternetGateway", "ec2:DetachInternetGateway", "ec2:DescribeInternetGateways",
      "ec2:CreateNatGateway", "ec2:DeleteNatGateway", "ec2:DescribeNatGateways",
      "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:DescribeRouteTables",
      "ec2:CreateRoute", "ec2:DeleteRoute",
      "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable", "ec2:ReplaceRouteTableAssociation",
      "ec2:AllocateAddress", "ec2:ReleaseAddress", "ec2:DescribeAddresses", "ec2:DescribeAddressesAttribute",
      "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup", "ec2:DescribeSecurityGroups", "ec2:DescribeSecurityGroupRules",
      "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
      "ec2:RunInstances", "ec2:TerminateInstances", "ec2:StartInstances", "ec2:StopInstances",
      "ec2:DescribeInstances", "ec2:DescribeInstanceTypes", "ec2:DescribeImages",
      "ec2:DescribeKeyPairs", "ec2:ModifyInstanceAttribute", "ec2:DescribeInstanceAttribute",
      "ec2:CreateLaunchTemplate", "ec2:DeleteLaunchTemplate", "ec2:DescribeLaunchTemplates",
      "ec2:DescribeLaunchTemplateVersions", "ec2:ModifyLaunchTemplate",
      "ec2:CreateLaunchTemplateVersion", "ec2:DeleteLaunchTemplateVersions",
      "ec2:CreateFlowLogs", "ec2:DeleteFlowLogs", "ec2:DescribeFlowLogs",
      "ec2:DescribeAvailabilityZones", "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeNetworkAcls", "ec2:DescribePrefixLists", "ec2:DescribeVpcEndpoints",
      "ec2:CreateTags", "ec2:DeleteTags", "ec2:DescribeTags"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "IAMOperations"
    effect = "Allow"
    actions = [
      "iam:GetRole", "iam:GetRolePolicy", "iam:CreateRole", "iam:DeleteRole",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy",
      "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListRoleTags",
      "iam:TagRole", "iam:UntagRole",
      "iam:GetInstanceProfile", "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
      "iam:PassRole",
      "iam:GetPolicy", "iam:CreatePolicy", "iam:DeletePolicy",
      "iam:GetPolicyVersion", "iam:CreatePolicyVersion", "iam:DeletePolicyVersion",
      "iam:ListPolicyVersions", "iam:ListPolicies", "iam:TagPolicy", "iam:UntagPolicy",
      "iam:GetOpenIDConnectProvider", "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider", "iam:ListOpenIDConnectProviders",
      "iam:TagOpenIDConnectProvider", "iam:UntagOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviderTags"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ECSOperations"
    effect = "Allow"
    actions = [
      "ecs:CreateCluster", "ecs:DeleteCluster", "ecs:DescribeClusters", "ecs:UpdateCluster",
      "ecs:CreateService", "ecs:DeleteService", "ecs:UpdateService", "ecs:DescribeServices",
      "ecs:RegisterTaskDefinition", "ecs:DeregisterTaskDefinition", "ecs:DescribeTaskDefinition",
      "ecs:ListClusters", "ecs:ListServices", "ecs:ListTaskDefinitions",
      "ecs:ListTasks", "ecs:DescribeTasks", "ecs:StopTask",
      "ecs:DescribeContainerInstances", "ecs:ListContainerInstances",
      "ecs:TagResource", "ecs:UntagResource", "ecs:ListTagsForResource",
      "ecs:PutClusterCapacityProviders", "ecs:UpdateClusterSettings"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ELBOperations"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DescribeLoadBalancers", "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:CreateTargetGroup", "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DescribeTargetGroups", "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:ModifyTargetGroup", "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets", "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:CreateListener", "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DescribeListeners", "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:CreateRule", "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:DescribeRules", "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags", "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:SetSecurityGroups", "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:AddListenerCertificates", "elasticloadbalancing:DescribeListenerCertificates"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AutoScalingOperations"
    effect = "Allow"
    actions = [
      "autoscaling:CreateAutoScalingGroup", "autoscaling:DeleteAutoScalingGroup",
      "autoscaling:DescribeAutoScalingGroups", "autoscaling:UpdateAutoScalingGroup",
      "autoscaling:CreateOrUpdateTags", "autoscaling:DeleteTags", "autoscaling:DescribeTags",
      "autoscaling:PutScalingPolicy", "autoscaling:DeletePolicy", "autoscaling:DescribePolicies",
      "autoscaling:SetDesiredCapacity", "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:DescribeScalingActivities", "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:AttachLoadBalancerTargetGroups", "autoscaling:DetachLoadBalancerTargetGroups",
      "autoscaling:DescribeLoadBalancerTargetGroups", "autoscaling:DescribeNotificationConfigurations"
    ]
    resources = ["*"]
  }
}

# ── Policy 2: Data & Storage ──────────────────────────────────────────────────
data "aws_iam_policy_document" "terraform_data" {
  statement {
    sid    = "SecretsManagerOperations"
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret", "secretsmanager:DeleteSecret",
      "secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue", "secretsmanager:UpdateSecret",
      "secretsmanager:RestoreSecret", "secretsmanager:ListSecrets",
      "secretsmanager:TagResource", "secretsmanager:UntagResource",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SSMOperations"
    effect = "Allow"
    actions = [
      "ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath",
      "ssm:PutParameter", "ssm:DeleteParameter", "ssm:DeleteParameters",
      "ssm:DescribeParameters", "ssm:ListTagsForResource",
      "ssm:AddTagsToResource", "ssm:RemoveTagsFromResource",
      "ssm:SendCommand", "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations", "ssm:ListCommands",
      "ssm:DescribeInstanceInformation"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "RDSOperations"
    effect = "Allow"
    actions = [
      "rds:CreateDBInstance", "rds:DeleteDBInstance", "rds:ModifyDBInstance",
      "rds:DescribeDBInstances", "rds:RebootDBInstance", "rds:StopDBInstance", "rds:StartDBInstance",
      "rds:CreateDBSubnetGroup", "rds:DeleteDBSubnetGroup",
      "rds:DescribeDBSubnetGroups", "rds:ModifyDBSubnetGroup",
      "rds:CreateDBParameterGroup", "rds:DeleteDBParameterGroup",
      "rds:DescribeDBParameterGroups", "rds:ModifyDBParameterGroup",
      "rds:ResetDBParameterGroup", "rds:DescribeDBParameters",
      "rds:CreateDBSnapshot", "rds:DeleteDBSnapshot", "rds:DescribeDBSnapshots",
      "rds:ListTagsForResource", "rds:AddTagsToResource", "rds:RemoveTagsFromResource",
      "rds:DescribeDBEngineVersions", "rds:DescribeOrderableDBInstanceOptions"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EFSOperations"
    effect = "Allow"
    actions = [
      "elasticfilesystem:CreateFileSystem", "elasticfilesystem:DeleteFileSystem",
      "elasticfilesystem:DescribeFileSystems", "elasticfilesystem:UpdateFileSystem",
      "elasticfilesystem:CreateAccessPoint", "elasticfilesystem:DeleteAccessPoint",
      "elasticfilesystem:DescribeAccessPoints",
      "elasticfilesystem:CreateMountTarget", "elasticfilesystem:DeleteMountTarget",
      "elasticfilesystem:DescribeMountTargets", "elasticfilesystem:DescribeMountTargetSecurityGroups",
      "elasticfilesystem:TagResource", "elasticfilesystem:UntagResource",
      "elasticfilesystem:ListTagsForResource",
      "elasticfilesystem:PutFileSystemPolicy", "elasticfilesystem:DescribeFileSystemPolicy",
      "elasticfilesystem:PutLifecycleConfiguration", "elasticfilesystem:DescribeLifecycleConfiguration"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ServiceDiscoveryOperations"
    effect = "Allow"
    actions = [
      "servicediscovery:CreatePrivateDnsNamespace", "servicediscovery:DeleteNamespace",
      "servicediscovery:GetNamespace", "servicediscovery:ListNamespaces",
      "servicediscovery:CreateService", "servicediscovery:DeleteService",
      "servicediscovery:GetService", "servicediscovery:UpdateService", "servicediscovery:ListServices",
      "servicediscovery:RegisterInstance", "servicediscovery:DeregisterInstance",
      "servicediscovery:ListInstances", "servicediscovery:GetInstance",
      "servicediscovery:TagResource", "servicediscovery:UntagResource",
      "servicediscovery:ListTagsForResource", "servicediscovery:GetOperation"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "S3Operations"
    effect = "Allow"
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
      "s3:ListBucket", "s3:ListBucketVersions",
      "s3:CreateBucket", "s3:DeleteBucket",
      "s3:GetBucketPolicy", "s3:PutBucketPolicy", "s3:DeleteBucketPolicy",
      "s3:GetBucketVersioning", "s3:PutBucketVersioning",
      "s3:GetBucketLogging", "s3:PutBucketLogging",
      "s3:GetBucketTagging", "s3:PutBucketTagging", "s3:DeleteBucketTagging",
      "s3:GetBucketPublicAccessBlock", "s3:PutBucketPublicAccessBlock",
      "s3:GetBucketEncryption", "s3:PutEncryptionConfiguration",
      "s3:GetLifecycleConfiguration", "s3:PutLifecycleConfiguration",
      "s3:GetBucketAcl", "s3:PutBucketAcl",
      "s3:GetBucketOwnershipControls", "s3:PutBucketOwnershipControls",
      "s3:GetBucketRequestPayment", "s3:GetAccountPublicAccessBlock"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DynamoDBStateLock"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem",
      "dynamodb:DeleteItem", "dynamodb:DescribeTable"
    ]
    resources = [
      "arn:aws:dynamodb:*:*:table/${var.terraform_lock_table}"
    ]
  }
}

# ── Policy 3: Monitoring & Platform ──────────────────────────────────────────
data "aws_iam_policy_document" "terraform_monitoring" {
  statement {
    sid    = "CloudWatchLogsOperations"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:DescribeAlarms",
      "cloudwatch:PutMetricData", "cloudwatch:GetMetricStatistics", "cloudwatch:ListMetrics",
      "cloudwatch:TagResource", "cloudwatch:UntagResource", "cloudwatch:ListTagsForResource",
      "cloudwatch:PutDashboard", "cloudwatch:DeleteDashboards",
      "cloudwatch:GetDashboard", "cloudwatch:ListDashboards",
      "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:DescribeLogGroups",
      "logs:CreateLogStream", "logs:DeleteLogStream", "logs:PutLogEvents",
      "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy",
      "logs:ListTagsForResource", "logs:ListTagsLogGroup",
      "logs:TagLogGroup", "logs:UntagLogGroup",
      "logs:TagResource", "logs:UntagResource",
      "logs:AssociateKmsKey", "logs:DisassociateKmsKey",
      "logs:DescribeLogStreams",
      "logs:PutSubscriptionFilter", "logs:DeleteSubscriptionFilter",
      "logs:DescribeSubscriptionFilters"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SNSOperations"
    effect = "Allow"
    actions = [
      "sns:CreateTopic", "sns:DeleteTopic",
      "sns:GetTopicAttributes", "sns:SetTopicAttributes",
      "sns:Subscribe", "sns:Unsubscribe",
      "sns:ListSubscriptionsByTopic",
      "sns:GetSubscriptionAttributes", "sns:SetSubscriptionAttributes",
      "sns:ListTopics", "sns:TagResource", "sns:UntagResource", "sns:ListTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ACMOperations"
    effect = "Allow"
    actions = [
      "acm:DescribeCertificate", "acm:ListCertificates",
      "acm:GetCertificate", "acm:ListTagsForCertificate"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Route53Operations"
    effect = "Allow"
    actions = [
      "route53:GetHostedZone", "route53:ListHostedZones", "route53:ListHostedZonesByName",
      "route53:ChangeResourceRecordSets", "route53:GetChange",
      "route53:ListResourceRecordSets", "route53:ListTagsForResource",
      "route53:ChangeTagsForResource"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "KMSOperations"
    effect = "Allow"
    actions = [
      "kms:DescribeKey", "kms:ListKeys", "kms:ListAliases",
      "kms:CreateGrant", "kms:RetireGrant", "kms:RevokeGrant",
      "kms:GenerateDataKey", "kms:Decrypt", "kms:Encrypt"
    ]
    resources = ["*"]
  }
}

# Managed policies — each document is independently sized (max 6,144 chars each)
# and does not count toward the 10,240-byte aggregate inline-policy limit.
resource "aws_iam_policy" "terraform_compute" {
  name        = "${var.role_name}-Compute"
  description = "GitHub Actions Terraform — compute & networking permissions"
  policy      = data.aws_iam_policy_document.terraform_compute.json
}

resource "aws_iam_policy" "terraform_data" {
  name        = "${var.role_name}-Data"
  description = "GitHub Actions Terraform — data & storage permissions"
  policy      = data.aws_iam_policy_document.terraform_data.json
}

resource "aws_iam_policy" "terraform_monitoring" {
  name        = "${var.role_name}-Monitoring"
  description = "GitHub Actions Terraform — monitoring & platform permissions"
  policy      = data.aws_iam_policy_document.terraform_monitoring.json
}

resource "aws_iam_role_policy_attachment" "terraform_compute" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.terraform_compute.arn
}

resource "aws_iam_role_policy_attachment" "terraform_data" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.terraform_data.arn
}

resource "aws_iam_role_policy_attachment" "terraform_monitoring" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.terraform_monitoring.arn
}

# Optional: Attach AWS managed policies
resource "aws_iam_role_policy_attachment" "readonly_access" {
  count      = var.attach_readonly_policy ? 1 : 0
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
