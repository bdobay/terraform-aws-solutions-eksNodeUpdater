provider "aws" {
  region = "us-east-1"
}

module "eksNodeUpdater" {
  source = "../.."
  run_schedule = "rate(10 minutes)"

}
