#!/bin/bash

# Variables

## Variables for VPC
vpc_cidr="10.0.0.0/25"

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
