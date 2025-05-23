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

## Variables for Elastic IP address
elastic_ip_name="NATGatewayAddress"

## Variables for NAT Gateway
nat_gtw_name="MyNATGateway"

# Creating Infrastructure

## Creating VPC
vpc_id=$(aws ec2 create-vpc \
--cidr-block $vpc_cidr \
--tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$vpc_name}]" \
--query 'Vpc.VpcId' \
--output text)

if [[ $? -eq 0 ]]; then
	echo "Created VPC"
else
	echo "An error occured while creating the VPC"
	exit 1
fi

## Creating Subnets

### Creating Public Subnet
pub_subnet_id=$(aws ec2 create-subnet \
--vpc-id $vpc_id \
--cidr-block $pub_subnet_cidr \
--tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value="$pub_subnet_name"}]" \
--query 'Subnet.SubnetId' \
--output text)

if [[ $? -eq 0 ]]; then
	echo "Created Public Subnet"
else
	echo "An error occured while creating Public Subnet"
	exit 1
fi

### Creating Private Subnet
priv_subnet_id=$(aws ec2 create-subnet \
--vpc-id $vpc_id \
--cidr-block $priv_subnet_cidr \
--tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value="$priv_subnet_name"}]" \
--query 'Subnet.SubnetId' \
--output text)

if [[ $? -eq 0 ]]; then
	echo "Created Private Subnet"
else
	echo "An error occured while creating Private Subnet"
	exit 1
fi

### Creating and attaching IGW

#### Creating IGW
igw_id=$(aws ec2 create-internet-gateway \
--tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$igw_name}]" \
--query 'InternetGateway.InternetGatewayId' \
--output text)

if [[ $? -eq 0 ]]; then
	echo "Created Internet Gateway"
else
	echo "An error occured while creating Internet Gateway"
	exit 1
fi

### Attaching IGW to VPC
aws ec2 attach-internet-gateway \
--internet-gateway-id $igw_id \
--vpc-id $vpc_id

if [[ $? -eq 0 ]]; then
	echo "Attached IGW to VPC"
else
	echo "An error occured while attaching IGW to VPC"
	exit 1
fi

## Creating Route Tables

### Creating Public Route Table
pub_rtb_id=$(aws ec2 create-route-table \
--vpc-id $vpc_id \
--tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$pub_rtb_name}]" \
--query 'RouteTable.RouteTableId' \
--output text)

if [[ $? -eq 0 ]]; then
	echo "Created Public Route Table" 
else
	echo "An error occured while creating Public Route Table"
	exit 1
fi

### Creating Private Route Table
priv_rtb_id=$(aws ec2 create-route-table \
--vpc-id $vpc_id \
--tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$priv_rtb_name}]" \
--query 'RouteTable.RouteTableId' \
--output text)

if [[ $? -eq 0 ]]; then
        echo "Created Private Route Table" 
else
        echo "An error occured while creating Private Route Table"
        exit 1
fi

## Creating Elastic IP address
elastic_ip_id=$(aws ec2 allocate-address \
--domain VPC \
--tag-specification "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$elastic_ip_name}]" \
--query 'AllocationId' \
--output text)

if [[ $? -eq 0 ]]; then
	echo "Created Elastic IP address"
else
	echo "An error occured while creating Elastic IP address"
	exit 1
fi

## Creating NAT Gateway
nat_gtw_id=$(aws ec2 create-nat-gateway \
--allocation-id $elastic_ip_id \
--subnet-id $pub_subnet_id \
--tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=$nat_gtw_name}]" \
--query 'NatGateway.NatGatewayId' \
--output text)

if [[ $? -eq 0 ]]; then
	echo "Created NAT Gateway"
else
	echo "An error occured while creating NAT Gateway"
	exit 1
fi
