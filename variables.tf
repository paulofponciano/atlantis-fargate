variable "aws_region" {
  description = "AWS Region (e.g. us-east-1, us-west-2, sa-east-1, us-east-2)"
  type        = string
}

variable "azs" {
  description = "AWS Availability Zones"
  type        = list(string)
}

variable "env_prefix" {
  description = "Environment prefix for all resources to be created."
  type        = string
}

variable "environment" {
  description = "Name of the application environment."
  type        = string
}

variable "tags" {
  description = "AWS Tags to add to all resources created."
  type        = map(string)
}

variable "site_domain" {
  description = "The primary domain name of the website."
  type        = string
}

variable "vpc_cidr" {
  description = "The VPC CIDR block."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets."
  type        = list(string)
}

variable "atlantis_github_user" {
  description = "The GitHub username for the Atlantis integration."
  type        = string
}

variable "atlantis_github_user_token" {
  description = "The personal access token for the GitHub user used by Atlantis."
  type        = string
}

variable "github_owner" {
  description = "Github owner to use when creating webhook."
  type        = string
}

variable "github_webhook_secret" {
  description = "Github webhook secret."
  type        = string
}

variable "atlantis_repo_allowlist" {
  description = "A comma-separated list of allowed GitHub repository URLs for Atlantis to operate on."
  type        = string
}

variable "repositories" {
  description = "List of GitHub repositories to create webhooks for. This is just the name of the repository, excluding the user or organization."
  type        = list(string)
}
