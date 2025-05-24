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

## Associating Subnets with Route Tables

### Associationg Public Subnet with Public Route Table
aws ec2 associate-route-table \
--route-table-id $pub_rtb_id \
--subnet-id $pub_subnet_id > /dev/null

if [[ $? -eq 0 ]]; then
	echo "Associated Public Subnet with Public Route Table"
else
	echo "An error occured while associating Public Subnet with Public Route Table"
	exit 1
fi

### Associating Private Subnet with Private Route Table
aws ec2 associate-route-table \
--route-table-id $priv_rtb_id \
--subnet-id $priv_subnet_id > /dev/null

if [[ $? -eq 0 ]]; then
	echo "Associated Private Subnet with Private Route Table"
else
	echo "An error occured while associating Private Subnet with Private Route Table"
	exit 1
fi

## Creating Security Groups

### Creating Bastion Security Group
bastion_sg_id=$(aws ec2 create-security-group \
--group-name "$bastion_sg_name" \
--description "$bastion_sg_description" \
--vpc-id $vpc_id \
--tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$bastion_sg_name}]" \
--query 'GroupId' \
--output text)

if [[ $? -eq 0 ]]; then
	echo "Created Bastion Security Group"
else
	echo "An error occured while creating Bastion Security Group"
	exit 1
fi

### Creating Private Security Group
priv_sg_id=$(aws ec2 create-security-group \
--group-name "$priv_sg_name" \
--description "$priv_sg_description" \
--vpc-id $vpc_id \
--tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$priv_sg_name}]" \
--query 'GroupId' \
--output text)

if [[ $? -eq 0 ]]; then
	echo "Created Private Security Group"
else
	echo "An error occured while creating Private Security Group"
	exit 1
fi

## Creating Ingress Rules for Security Groups

### Creating Bastion Security Group Ingress Rule for SSH
aws ec2 authorize-security-group-ingress \
--group-id $bastion_sg_id \
--protocol tcp \
--port 22 \
--cidr $my_ip > /dev/null

if [[ $? -eq 0 ]]; then
	echo "Authorized SSH Ingress for Bastion Security Group from the public IP address of this host"
else
	echo "An error occured while authorizing SSH Ingress for Bastion Security Group"
	exit 1
fi

### Creating Private Security Group Ingress Rule for SSH
aws ec2 authorize-security-group-ingress \
--group-id $priv_sg_id \
--protocol tcp \
--port 22 \
--cidr $pub_subnet_cidr > /dev/null

if [[ $? -eq 0 ]]; then
	echo "Authorized SSH Ingress for Private Security Group from the Public Subnet"
else
	echo "An error occured while authorizing SSH Ingress for Private Security Group"
	exit 1
fi

## Allocating Elastic IP address
elastic_ip_id=$(aws ec2 allocate-address \
--domain VPC \
--tag-specification "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$elastic_ip_name}]" \
--query 'AllocationId' \
--output text)

if [[ $? -eq 0 ]]; then
	echo "Allocated Elastic IP address"
else
	echo "An error occured while allocating Elastic IP address"
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

## Creating Routes

### Creating IGW Route
aws ec2 create-route \
--route-table-id $pub_rtb_id \
--destination-cidr-block $igw_route_dest_cidr \
--gateway-id $igw_id > /dev/null

if [[ $? -eq 0 ]]; then
	echo "Created Route to Internet Gateway"
else
	echo "An error occured while creating Route to Internet Gateway"
	exit 1
fi

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

if [[ $? -eq 0 ]]; then
	echo "Created Route to NAT Gateway"
else
	echo "An error occured while creating Route to NAT Gateway"
	exit 1
fi

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

if [[ $? -eq 0 ]]; then
	echo "Created Bastion Host"
else
	echo "An error occured while creating Bastion Host"
	exit 1
fi