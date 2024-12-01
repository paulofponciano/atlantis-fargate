data "aws_caller_identity" "current" {}

module "vpc" {
  source                 = "terraform-aws-modules/vpc/aws"
  name                   = "${var.env_prefix}-${var.environment}-vpc"
  cidr                   = var.vpc_cidr
  azs                    = var.azs
  private_subnets        = var.private_subnet_cidrs
  public_subnets         = var.public_subnet_cidrs
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = false
  tags                   = var.tags
  version                = ">=2.0"
  enable_dns_hostnames   = true
}

module "acm" {
  source            = "terraform-aws-modules/acm/aws"
  version           = ">= v2.0"
  domain_name       = var.site_domain
  zone_id           = data.aws_route53_zone.this.zone_id
  validation_method = "DNS"
  tags              = var.tags
}

module "alb" {
  source                     = "terraform-aws-modules/alb/aws"
  version                    = ">= 5.0"
  name                       = "${var.env_prefix}-${var.environment}"
  load_balancer_type         = "application"
  vpc_id                     = module.vpc.vpc_id
  subnets                    = module.vpc.public_subnets
  security_groups            = [aws_security_group.alb.id]
  enable_deletion_protection = false
  tags                       = var.tags
}

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "5.6.0"

  # Cluster
  cluster_name = "${var.env_prefix}-${var.environment}-cluster"
  cluster_settings = {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

resource "random_password" "webhook_secret" {
  length  = 32
  special = false
}

module "secrets_manager" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "~> 1.0"

  for_each = {
    github-token = {
      secret_string = var.atlantis_github_user_token
    }
    github-webhook-secret = {
      secret_string = var.github_webhook_secret
    }
  }

  name_prefix             = each.key
  recovery_window_in_days = 0
  secret_string           = each.value.secret_string

  tags = var.tags
}

module "atlantis" {
  source = "terraform-aws-modules/atlantis/aws"

  name = "${var.env_prefix}-${var.environment}"

  # Existing cluster
  create_cluster = false
  cluster_arn    = module.ecs_cluster.arn

  # Existing ALB
  create_alb            = false
  alb_target_group_arn  = aws_lb_target_group.blue.arn
  alb_security_group_id = aws_security_group.alb.id

  # ECS Container Definition
  atlantis = {
    environment = [
      {
        name  = "ATLANTIS_GH_USER"
        value = "${var.atlantis_github_user}"
      },
      {
        name  = "ATLANTIS_REPO_ALLOWLIST"
        value = "${var.atlantis_repo_allowlist}"
      },
      {
        name  = "ATLANTIS_ATLANTIS_URL"
        value = "https://${var.site_domain}"
      },
      {
        name  = "ATLANTIS_ENABLE_DIFF_MARKDOWN_FORMAT"
        value = "true"
      },
      {
        name  = "ATLANTIS_WEB_BASIC_AUTH"
        value = "true"
      },
      {
        name  = "ATLANTIS_WEB_USERNAME"
        value = "admin"
      },
      {
        name  = "ATLANTIS_WEB_PASSWORD"
        value = "supersecret"
      },
      {
        name  = "ATLANTIS_REPO_CONFIG_JSON",
        value = jsonencode(yamldecode(file("${path.module}/server-atlantis.yaml"))),
      },
    ]
    secrets = [
      {
        name      = "ATLANTIS_GH_TOKEN"
        valueFrom = try(module.secrets_manager["github-token"].secret_arn, "")
      },
      {
        name      = "ATLANTIS_GH_WEBHOOK_SECRET"
        valueFrom = try(module.secrets_manager["github-webhook-secret"].secret_arn, "")
      },
    ]
  }

  # ECS Service
  service = {
    task_exec_secret_arns = [for sec in module.secrets_manager : sec.secret_arn]
    # Provide Atlantis permission necessary to create/destroy resources
    tasks_iam_role_policies = {
      AdministratorAccess = "arn:aws:iam::aws:policy/AdministratorAccess"
    }
  }
  service_subnets = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id
  tags            = var.tags
}

# module "github_repository_webhooks" {
#   source = "./modules/github-repository-webhook"

#   repositories = var.repositories

#   webhook_url    = "https://${var.site_domain}/events"
#   webhook_secret = random_password.webhook_secret.result
# }
