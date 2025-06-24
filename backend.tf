terraform {
  backend "s3" {
    bucket       = "uc-15-service-catalog"
    key          = "uc-15-service-catalog"
    region       = "us-west-1"
    encrypt      = true
    use_lockfile = true
  }
}