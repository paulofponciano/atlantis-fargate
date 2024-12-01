provider "aws" {
  region = var.aws_region
}

provider "github" {
  token = var.atlantis_github_user_token
  owner = var.github_owner
}
