#!/bin/bash

# Variables

## Variables for VPC
vpc_cidr="10.0.0.0/25"

## Variables for creating Subnets
pub_subnet_cidr="10.0.0.0/28"
priv_subnet_cidr="10.0.0.64/26"

# Creating Infrastructure

## Creating VPC
vpc_id=$(aws ec2 create-vpc \
--cidr-block $vpc_cidr \
--tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value="MyVpc"}]' \
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
--tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value="MyPublicSubnet"}]' \
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
--tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value="MyPrivateSubnet"}]' \
--query 'Subnet.SubnetId' \
--output text)

if [[ $? -eq 0 ]]; then
	echo "Created Private Subnet"
else
	echo "An error occured while creating Private Subnet"
	exit 1
fi
