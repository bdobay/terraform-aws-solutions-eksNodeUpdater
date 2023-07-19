# AWS EKS Terraform module

Terraform module to periodically update EKS worker nodes to the latest patched AMI for the current version i.e 1.23.   
The job runs on an EC2 instance. 

## Solution Components

- CloudWatch Events schedule rule
- Lambda function
- EC2 Launch Template

## Usage
```
module "eksNodeUpdater" {
  source = "../.."
  vpc_id = "vpc-123456"
  subnet_id = "subnet-123456"

  ##run_schedule in UTC time 
  run_schedule = "cron(0 12 ? * FRI *)"

}

```

## Overview

A scheduled EC2 (via CloudWatch Events + Lambda) is provisioned per the run schedule.  

For all clusters and node-groups in an account region (per the EC2 region), eksctl will update the EKS AMI to the latest available patch version
i.e 1.23.abc -> 1.23.def.

The updating only happens on the data plane and not the control plane.

The AMI will not update to a different minor version i.e 1.23 -> 1.24, only the latest patch for the current minor release.

Patch version updates will never deprecate API's - they are purely AWS patches not Kubernetes updates. 

If the latest AMI is being used, the update will still show as occurring and appear in the node-group update history however the CloudWatch logs will only show the update taking approx 30 secs.

Only AWS managed AMI's will be updated i.e EKS Amazon Linux, Bottlerocket.. custom AMI's will be skipped.

All logs are sent to CloudWatch log group: 'eksNodeUpdater.log'.

Once all node-groups from all clusters in the region are updated, the EC2 will terminate itself.

EC2 needs to have outbound internet access to download software packages.

## Important

specificsubnet example should be most commonly used.

EC2 must be scheduled into a public subnet (i.e subnet with route table pointing to Internet Gateway)

If deployed into private subnet, EC2 will need to be terminated (or will run indefinitely) and redeployed to public subnet. 

run_schedule uses UTC time 

## Examples

- defaultvpcsubnet: Provision EC2 to the default VPC and subnet
- specificsubnet: Provision EC2 into specific VPC and subnet
