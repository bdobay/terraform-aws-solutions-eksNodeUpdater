variable "vpc_id" {
  type = string
  description = "VPC for eksNodeUpdater to be created in."
  default = ""
}

variable "subnet_id" {
  type = string
  description = "Public subnet for eksNodeUpdater to be created in."
  default = ""
}

variable "run_schedule" {
  type = string
  description = "For example, cron(0 20 * * ? *) in UTC time or rate(1 minute) or rate(2 minutes)"
}