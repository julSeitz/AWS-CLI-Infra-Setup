#!/bin/bash

# Variables

# Variables for VPC
vpc_cidr="10.0.0.0/25"

# Creating Infrastructure

vpc_id=$(aws ec2 create-vpc \
--cidr-block $vpc_cidr \
--tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value="MyVpc"}]' \
--query 'Vpc.VpcId' \
--output text)

echo "Created VPC"
echo "VPC ID $vpc_id"
