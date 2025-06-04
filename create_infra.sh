#!/bin/bash

# Variables

## Variables for VPC
vpc_cidr="10.0.0.0/25"
vpc_name="MyVpc"

## Variables for creating Subnets
pub_subnet_cidr="10.0.0.0/28"
pub_subnet_name="MyPublicSubnet"

priv_subnet_cidr="10.0.0.64/26"
priv_subnet_name="MyPrivateSubnet"

## Variables for Internet Gateway (IGW)
igw_name="MyIgw"

## Variables for Route Tables
pub_rtb_name="PublicRouteTable"
priv_rtb_name="PrivateRouteTable"

## Variables for Security Groups
bastion_sg_name="BastionSecurityGroup"
bastion_sg_description="Allow SSH from my IP"

priv_sg_name="PrivateSecurityGroup"
priv_sg_description="Allow SSH only from Public Subnet"

## Variables for Security Group Rules
my_ip="$(curl -s -4 ifconfig.me)/32"

## Variables for Elastic IP address
elastic_ip_name="NATGatewayAddress"

## Variables for NAT Gateway
nat_gtw_name="MyNATGateway"

## Variables for Routes
igw_route_dest_cidr="0.0.0.0/0"
nat_gtw_route_dest_cidr="0.0.0.0/0"

## Variables for Instances
ami_id="ami-04999cd8f2624f834"
instance_type="t3.micro"
key_name="vockey"
pub_instance_name="BastionHost"

user_data_path="file://user_data.txt"

priv_instance_name="PrivateInstance"

# Functions

# Function to check for errors and output success or failure
function check_error() {
	local exit_status=$?
	local action="$1"
	local resource_name="$2"
	if [[ $exit_status -eq 0 ]]; then
		echo "Created $resource_name"
	else
		echo "An error occured while $action $resource_name"
		exit 1
	fi
}

##########################################
# Creating a VPC
# Globals:
#	None
# Arguments:
#	Name of the varible the VPC ID should be written to
#	CIDR range of the VPC
#	Name of the VPC
# Outputs:
#	Writes ID of the created VPC to variable
##########################################
function create_vpc() {
	# Setting the name of the variable to be filled
	local -n ret="$1"
	local cidr="$2"
	local name="$3"

	# Filling variable of given name with return value
	ret=$(aws ec2 create-vpc \
	--cidr-block "$cidr" \
	--tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$name}]" \
	--query 'Vpc.VpcId' \
	--output text)

	check_error "creating" "VPC"
}

##########################################
# Creating a Subnet
# Globals:
#	None
# Arguments:
#	Name of the varible the SubnetID should be written to
#	ID of the Subnets VPC
#	CIDR range of the Subnet
#	Name of the Subnet
# Outputs:
#	Writes ID of the created Subnet to variable
##########################################
function create_subnet() {
	# Setting the name of the variable to be filled
	local -n ret="$1"
	local vpc_id="$2"
	local cidr="$3"
	local name="$4"

	# Filling variable of given name with return value
	ret=$(aws ec2 create-subnet \
	--vpc-id $vpc_id \
	--cidr-block $cidr \
	--tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value="$name"}]" \
	--query 'Subnet.SubnetId' \
	--output text)

	check_error "creating" "$name Subnet"
}

# Creating Infrastructure

## Creating VPC

create_vpc "vpc_id" "$vpc_cidr" "$vpc_name"

## Creating Subnets

### Creating Public Subnet
create_subnet "pub_subnet_id" "$vpc_id" "$pub_subnet_cidr" "$pub_subnet_name"

### Creating Private Subnet
create_subnet "priv_subnet_id" "$vpc_id" "$priv_subnet_cidr" "$priv_subnet_name"

### Creating and attaching IGW

#### Creating IGW
igw_id=$(aws ec2 create-internet-gateway \
--tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$igw_name}]" \
--query 'InternetGateway.InternetGatewayId' \
--output text)

check_error "creating" "IGW"

### Attaching IGW to VPC
aws ec2 attach-internet-gateway \
--internet-gateway-id $igw_id \
--vpc-id $vpc_id

check_error "attaching" "IGW"

## Creating Route Tables

### Creating Public Route Table
pub_rtb_id=$(aws ec2 create-route-table \
--vpc-id $vpc_id \
--tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$pub_rtb_name}]" \
--query 'RouteTable.RouteTableId' \
--output text)

check_error "creating" "Public Route Table"

### Creating Private Route Table
priv_rtb_id=$(aws ec2 create-route-table \
--vpc-id $vpc_id \
--tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$priv_rtb_name}]" \
--query 'RouteTable.RouteTableId' \
--output text)

check_error "creating" "Private Route Table"

## Associating Subnets with Route Tables

### Associationg Public Subnet with Public Route Table
aws ec2 associate-route-table \
--route-table-id $pub_rtb_id \
--subnet-id $pub_subnet_id > /dev/null

check_error "associating" "Public Subnet"

### Associating Private Subnet with Private Route Table
aws ec2 associate-route-table \
--route-table-id $priv_rtb_id \
--subnet-id $priv_subnet_id > /dev/null

check_error "associating" "Private Subnet"

## Creating Security Groups

### Creating Bastion Security Group
bastion_sg_id=$(aws ec2 create-security-group \
--group-name "$bastion_sg_name" \
--description "$bastion_sg_description" \
--vpc-id $vpc_id \
--tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$bastion_sg_name}]" \
--query 'GroupId' \
--output text)

check_error "creating" "Bastion Security Group"

### Creating Private Security Group
priv_sg_id=$(aws ec2 create-security-group \
--group-name "$priv_sg_name" \
--description "$priv_sg_description" \
--vpc-id $vpc_id \
--tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$priv_sg_name}]" \
--query 'GroupId' \
--output text)

check_error "creating" "Private Security Group"

## Creating Ingress Rules for Security Groups

### Creating Bastion Security Group Ingress Rule for SSH
aws ec2 authorize-security-group-ingress \
--group-id $bastion_sg_id \
--protocol tcp \
--port 22 \
--cidr $my_ip > /dev/null

check_error "authorizing" "SSH Ingress for Bastion Security Group"

### Creating Private Security Group Ingress Rule for SSH
aws ec2 authorize-security-group-ingress \
--group-id $priv_sg_id \
--protocol tcp \
--port 22 \
--cidr $pub_subnet_cidr > /dev/null

check_error "authorizing" "SSH Ingress for Private Security Group"

## Allocating Elastic IP address
elastic_ip_id=$(aws ec2 allocate-address \
--domain VPC \
--tag-specification "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$elastic_ip_name}]" \
--query 'AllocationId' \
--output text)

check_error "allocating" "Elastic IP"

## Creating NAT Gateway
nat_gtw_id=$(aws ec2 create-nat-gateway \
--allocation-id $elastic_ip_id \
--subnet-id $pub_subnet_id \
--tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=$nat_gtw_name}]" \
--query 'NatGateway.NatGatewayId' \
--output text)

check_error "creating" "NAT Gateway"

## Creating Routes

### Creating IGW Route
aws ec2 create-route \
--route-table-id $pub_rtb_id \
--destination-cidr-block $igw_route_dest_cidr \
--gateway-id $igw_id > /dev/null

check_error "creating" "Route to IGW"

### Waiting until NAT Gateway is available
echo "Waiting for NAT Gateway to become available..."
while [[ true ]]; do
	nat_gtw_state=$(aws ec2 describe-nat-gateways \
	--nat-gateway-id $nat_gtw_id \
	--query 'NatGateways[*].State' \
	--output text)
	if [[ $nat_gtw_state = "available" ]]; then
		echo "NAT Gateway is available!"
		break
	else
		sleep 10
	fi
done

### Creating Nat Gateway Route
aws ec2 create-route \
--route-table-id $priv_rtb_id \
--destination-cidr-block $nat_gtw_route_dest_cidr \
--nat-gateway-id $nat_gtw_id > /dev/null

check_error "creating" "Route to NAT Gateway"

## Creating EC2 Instances

### Creating Bastion Host
aws ec2 run-instances \
--image-id $ami_id \
--instance-type $instance_type \
--key-name $key_name \
--security-group-id $bastion_sg_id \
--subnet-id $pub_subnet_id \
--user-data $user_data_path \
--associate-public-ip-address \
--tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$pub_instance_name}]" > /dev/null

check_error "creating" "Bastion Host"

## Creating Private Instance
aws ec2 run-instances \
--image-id $ami_id \
--instance-type $instance_type \
--key-name $key_name \
--security-group-id $priv_sg_id \
--subnet-id $priv_subnet_id \
--user-data $user_data_path \
--tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$priv_instance_name}]" > /dev/null

check_error "creating" "Private Instance"