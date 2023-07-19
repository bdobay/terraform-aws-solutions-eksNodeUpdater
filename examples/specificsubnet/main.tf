provider "aws" {
  region = "us-east-1"
}



module "eksNodeUpdater" {
  source = "../.."
  vpc_id = "vpc-123456"
  subnet_id = "subnet-123456"

  ##run_schedule in UTC time 
  run_schedule = "cron(0 12 ? * FRI *)"

}
