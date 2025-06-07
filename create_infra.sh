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
##########################################
# Checks for errors of last AWS CLI command and outputs result
# Globals:
#	$? Last exit code
# Arguments:
#	Action the last command was attempting
#	Resource the last command was working with
# Outputs:
#	Writes success or failure to stdout
##########################################
function check_error() {
	local exit_status=$?
	local action="$1"
	local resource_name="$2"
	if [[ $exit_status -eq 0 ]]; then
		echo "Finished $action $resource_name"
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

##########################################
# Creating an Internet Gateway
# Globals:
#	None
# Arguments:
#	Name of the varible the IGWID should be written to
#	Name of the IGW
# Outputs:
#	Writes ID of the created IGW to variable
##########################################
function create_igw() {
	# Setting the name of the variable to be filled
	local -n ret="$1"
	local name="$2"
    
	# Filling variable of given name with return value
    ret=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$name}]" \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)
    
    check_error "creating" "Internet Gateway"
}

##########################################
# Attaching IGW to VPC
# Globals:
#	None
# Arguments:
#	ID of the IGW to attach
#	ID of the VPC to attach IGW to
# Outputs:
#	None
##########################################
function attaching_igw() {
	local igw_id=$1
	local vpc_id=$2

	aws ec2 attach-internet-gateway \
	--internet-gateway-id "$igw_id" \
	--vpc-id "$vpc_id"

	check_error "attaching" "IGW"
}

##########################################
# Creating Route Table
# Globals:
#	None
# Arguments:
#	Name of the varible the RTB-ID should be written to
#	ID of the Subnet
#	Name of the Route Table
# Outputs:
#	Writes ID of the created Route Table to variable
##########################################
function create_route_table() {
	# Setting the name of the variable to be filled
	local -n ret="$1"
	local vpc_id="$2"
	local name="$3"

	# Filling variable of given name with return value
	ret=$(aws ec2 create-route-table \
	--vpc-id "$vpc_id" \
	--tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$name}]" \
	--query 'RouteTable.RouteTableId' \
	--output text)

	check_error "creating" "$name RouteTable"
}

##########################################
# Associating Route Table with Subnet
# Globals:
#	None
# Arguments:
#	ID of the Route Table
#	ID of the Subnet
#	Name of the Subnet
# Outputs:
#	None
##########################################
function associate_subnet_with_rtb() {
	local rtb_id="$1"
	local subnet_id="$2"
	local subnet_name="$3"

	aws ec2 associate-route-table \
	--route-table-id "$rtb_id" \
	--subnet-id "$subnet_id" > /dev/null

	check_error "associating" "$subnet_name Subnet"
}

##########################################
# Creating Security Group
# Globals:
#	None
# Arguments:
#	Name of the varible the SG-ID should be written to
#	Name of the SG
#	Description of the SG
#	ID of the VPC
# Outputs:
#	Writes ID of the created SG to variable
##########################################
function create_security_group() {
	# Setting the name of the variable to be filled
	local -n ret="$1"
	local name="$2"
	local description="$3"
	local vpc_id="$4"

	# Filling variable of given name with return value
	ret=$(aws ec2 create-security-group \
	--group-name "$name" \
	--description "$description" \
	--vpc-id "$vpc_id" \
	--tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$name}]" \
	--query 'GroupId' \
	--output text)

	check_error "creating" "$name Security Group"
}

##########################################
# Authorizing ingress to a SG from specific source
# Globals:
#	None
# Arguments:
#	Name of the SG
#	ID of the SG
#	Protocol to authorize
#	Port to authorize
#	Type of the authorized source, either 'ip' or 'sg'
#	Source to authorize ingress from
# Outputs:
#	None
##########################################
function authorize_sg_ingress_from_source() {
	# Setting local variables
	local name="$1"
	local sg_id="$2"
	local protocol="$3"
	local port="$4"
	local source_type="$5"
	local authorized_source="$6"
	local option

	# Setting option based on given source type type
	if [[ "$source_type" == "ip" ]]; then
		option="--cidr"
	elif [[ "$source_type" == "sg" ]]; then
		option="--source-group"
	else
		echo "Invalid argument for source_type. Only 'ip' or 'sg' are allowed."
		exit 1
	fi

	aws ec2 authorize-security-group-ingress \
	--group-id "$sg_id" \
	--protocol "$protocol" \
	--port "$port" \
	"$option" "$authorized_source" > /dev/null

	check_error "authorizing" "ingress on $protocol port $port for $name from $authorized_source"
}

##########################################
# Allocating Elastic IP address
# Globals:
#	None
# Arguments:
#	Name of the varible the Elastic IP ID should be written to
#	Name of the Elastic IP
# Outputs:
#	Writes ID of the allocated Elastic IP to variable
##########################################
function allocate_elastic_ip() {
	# Setting the name of the variable to be filled
	local -n ret="$1"
	local name="$2"

	# Filling variable of given name with return value
	ret=$(aws ec2 allocate-address \
	--domain VPC \
	--tag-specification "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$name}]" \
	--query 'AllocationId' \
	--output text)

	check_error "allocating" "Elastic IP $name"
}


##########################################
# Creating NAT Gateway and waiting until it is available
# Globals:
#	None
# Arguments:
#	Name of the varible the NAT-Gateway-ID should be written to
#	Name of the NAT Gateway
#	ID of the Elastic IP to assign to the NAT Gateway
#	ID of the subnet to place the NAT Gateway in
# Outputs:
#	Writes ID of the created NAT Gateway to variable
##########################################
function create_nat_gateway() {
	# Setting the name of the variable to be filled
	local -n ret="$1"
	local name="$2"
	local elastic_ip_id="$3"
	local subnet_id="$4"

	# Filling variable of given name with return value
	ret=$(aws ec2 create-nat-gateway \
	--allocation-id $elastic_ip_id \
	--subnet-id $subnet_id \
	--tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=$name}]" \
	--query 'NatGateway.NatGatewayId' \
	--output text)

	check_error "creating" "NAT Gateway $name"

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
}

##########################################
# Creating route to given gateway
# Globals:
#	None
# Arguments:
#	ID of the route table to use
#	Target CIDR block this route is used for
#	Gateway type, either 'igw' or 'nat'
#	ID of the gateway to route to
# Outputs:
#	None
##########################################
function create_route_to_gateway() {
	# Setting local variables
	local rtb_id="$1"
	local destination_cidr_block="$2"
	local gateway_type="$3"
	local gateway_id="$4"
	local option

	# Setting option based on given gateway type
	if [[ "$gateway_type" == "nat" ]]; then
		option="--nat-gateway-id"
	elif [[ "$gateway_type" == "igw" ]]; then
		option="--gateway-id"
	else
		echo "Invalid argument for gateway_type. Only 'nat' or 'igw' are allowed."
		exit 1
	fi

	# Creating route
	aws ec2 create-route \
	--route-table-id "$rtb_id" \
	--destination-cidr-block "$destination_cidr_block" \
	"$option" "$gateway_id" > /dev/null

	# Checking exit code for errors
	check_error "creating" "Route to Gateway $gateway_id"
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
create_igw "igw_id" "$igw_name"

### Attaching IGW to VPC
attaching_igw "$igw_id" "$vpc_id"

## Creating Route Tables

### Creating Public Route Table
create_route_table "pub_rtb_id" "$vpc_id" "$pub_rtb_name"

### Creating Private Route Table
create_route_table "priv_rtb_id" "$vpc_id" "$priv_rtb_name"

## Associating Subnets with Route Tables

### Associationg Public Subnet with Public Route Table
associate_subnet_with_rtb "$pub_rtb_id" "$pub_subnet_id" "$pub_subnet_name"

### Associating Private Subnet with Private Route Table
associate_subnet_with_rtb "$priv_rtb_id" "$priv_subnet_id" "$priv_subnet_name"

## Creating Security Groups

### Creating Bastion Security Group
# Deliberate nonsense instead of VPC id
create_security_group "bastion_sg_id" "$bastion_sg_name" "$bastion_sg_description" "$vpc_id"

### Creating Private Security Groupgateway
create_security_group "priv_sg_id" "$priv_sg_name" "$priv_sg_description" "$vpc_id"

## Creating Ingress Rules for Security Groups

protocol="tcp"
port="22"
source_type="ip"

### Creating Bastion Security Group Ingress Rule for SSH
authorize_sg_ingress_from_source "$bastion_sg_name" "$bastion_sg_id" "$protocol" "$port" "$source_type" "$my_ip"

### Creating Private Security Group Ingress Rule for SSH
authorize_sg_ingress_from_source "$priv_sg_name" "$priv_sg_id" "$protocol" "$port" "$source_type" "$pub_subnet_cidr"

## Allocating Elastic IP address
allocate_elastic_ip "elastic_ip_id" "$elastic_ip_name"

## Creating NAT Gateway
create_nat_gateway "nat_gtw_id" "$nat_gtw_name" "$elastic_ip_id" "$pub_subnet_id"

## Creating Routes

### Creating IGW Route
create_route_to_gateway "$pub_rtb_id" "$igw_route_dest_cidr" "igw" "$igw_id"

### Creating Nat Gateway Route
create_route_to_gateway "$priv_rtb_id" "$nat_gtw_route_dest_cidr" "nat" "$nat_gtw_id"

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