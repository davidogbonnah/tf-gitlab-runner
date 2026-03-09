terraform {
  backend "s3" {
    bucket       = "dcopro-tfstate"
    key          = "tf-gitlab-runner/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
    encrypt      = true
  }
}