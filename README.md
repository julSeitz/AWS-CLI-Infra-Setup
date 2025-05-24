
# AWS-CLI-Infra-Setup

A bash script using the [AWS CLI](https://aws.amazon.com/cli/) to create a [VPC](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html) with two [subnets](https://docs.aws.amazon.com/vpc/latest/userguide/configure-subnets.html) and two [EC2](https://aws.amazon.com/ec2/) instances within them.  
Both EC2 instances can be connected to via SSH, with several security measures taken:
- the Bastion Host can only be connected to via SSH from the public IP address of the host executing the script
- the Private Instance can only be connected to via SSH from the Public Subnet, not directly.

## Prerequisites

To use this script, you must have
- a bash shell
- the AWS CLI version 2.27 installed and configured
- the [IAM](https://aws.amazon.com/iam/) permissions to
    - create VPCs
    - create Subnets
    - create [Internet Gateways](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html)
    - attach Internet Gateways to VPCs
    - create [Route Tables](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html)
    - associating Route Tables with Subnets
    - create Routes
    - create [Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html)
    - define Security Group Rules
    - allocating [Elastic IP addresses](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html)
    - creating [NAT Gateways](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html)
    - creating EC2 instances

## Installation

To install the script, clone this repository.  
Make sure the above prerequisites are met and you have local execution permissions for the script.

## Running the script

### GUI

In the directory of this repository, double-click on the file named `create_infra.sh`.

### Shell

Either:
- Navigate to the directory of this repository and call the script with: `./create_infra.sh`.
- Call the script by it's path, for example: `/your/path/to/repository/AWS-CLI-Infra-Setup/create_infra.sh`.

## Adjusting variables

At the beginning of the script a number of variables are defined.  
These include:
- Names for resources
- CIDR ranges for VPC and subnets
- Descriptions of some resources
- the [Amazon Machine Image](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) to use for the EC2 instances
- the [instance type](https://aws.amazon.com/ec2/instance-types/)
- the name of the [key pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) to use
- the [user data script](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html) to run at instance startup

To change details of this setup, adjust the variables as needed.  
Keep in mind that the variables only determine details about the resources, not the kind or amount of resources.