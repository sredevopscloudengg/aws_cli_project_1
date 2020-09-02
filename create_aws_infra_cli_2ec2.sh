#this script will create two ec2 instances, with the required networking infrastructure, bootstrap them with tomcat and finally add them to a load balancer
#!/bin/bash

echo 'AWSCLI Create Script -> 2 ec2 instances'

#Create VPC
echo "**************Creating VPC**************"
vpc_id=$(aws ec2 create-vpc --cidr-block 12.0.0.0/16 --query Vpc.VpcId --output text)
aws ec2 wait vpc-available --vpc-ids $vpc_id
echo "**************VPC AVAILABLE**************"
echo "VPC ID - $vpc_id"

#Check VPC State
echo "**************Checking VPC STATE**************"
vpc_state=$(aws ec2 describe-vpcs --vpc-id $vpc_id --query Vpcs[].State --output text)
echo "VPC STATE - $vpc_state"

#Find VPC CidrBlock
vpc_cidr_block=$(aws ec2 describe-vpcs --vpc-id $vpc_id --query Vpcs[].CidrBlock --output text)
echo "VPC CIDR - $vpc_cidr_block"

#Create Internet Gateway
echo "**************Creating INTERNET GATEWAY**************"
igw_id=$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text)
sleep 5
: '
igw_id=$(aws ec2 describe-internet-gateways --query InternetGateways[].InternetGatewayId --output text)
while true;
do
        if [ ${#igw_id} -gt 0 ]
        then
                break
        else
                igw_id=$(aws ec2 describe-internet-gateways --query InternetGateways[].InternetGatewayId --output text)
                sleep 2
        fi
done
echo "**************INTERNET GATEWAY $igw_id Created**************"
echo "INTERNET GATEWAY ID - $igw_id"
'

#Attach Internet Gateway
echo "**************Attaching INTERNET GATEWAY**************"
aws ec2 attach-internet-gateway --internet-gateway-id $igw_id --vpc-id $vpc_id

#Find Internet Gateway State
echo "**************Checking Internet GATEWAY STATE**************"
igw_state=$(aws ec2 describe-internet-gateways --query InternetGateways[].Attachments[].State --internet-gateway-ids $igw_id --output text)
while true;
do
        if [ ${#igw_state} -gt 0 ]
        then
                break
        else
		igw_state=$(aws ec2 describe-internet-gateways --query InternetGateways[].Attachments[].State --internet-gateway-ids $igw_id --output text)
                sleep 2
        fi
done
echo "INTERNET GATEWAY STATE - $igw_state"

#Find Internet Gateway VpcId
igw_vpcid=$(aws ec2 describe-internet-gateways --query InternetGateways[].Attachments[].VpcId --internet-gateway-ids $igw_id --output text)
echo "INTERNET GATEWAY ASSOCIATED VPC ID - $igw_vpcid"

#Create Subnet
echo "**************Creating SUBNET**************"
subnet_id1=$(aws ec2 create-subnet --availability-zone us-east-1a --cidr-block 12.0.1.0/24 --vpc-id $vpc_id --query Subnet.SubnetId --output text)
aws ec2 wait subnet-available --subnet-ids $subnet_id1
echo "************SUBNET1 AVAILABLE**************"
echo "SUBNET1 - $subnet_id1"

#Find Subnet State
subnet_id1_state=$(aws ec2 describe-subnets --subnet-ids $subnet_id1 --query Subnet.State --output text)
echo "**************SUBNET1 STATE - $subnet_id1_state**************"
echo "SUBNET1 STATE - $subnet_id1_state"

#Create Subnet2
echo "**************Creating SUBNET2**************"
subnet_id2=$(aws ec2 create-subnet --availability-zone us-east-1b --cidr-block 12.0.2.0/24 --vpc-id $vpc_id --query Subnet.SubnetId --output text)
aws ec2 wait subnet-available --subnet-ids $subnet_id2
echo "**************SUBNET2 AVAILABLE**************"
echo "SUBNET2 - $subnet_id2"

#Find Subnet State2
subnet_id2_state=$(aws ec2 describe-subnets --subnet-ids $subnet_id2 --query Subnet.State --output text)
echo "**************SUBNET2 STATE - $subnet_id2_state**************"
echo "SUBNET2 STATE - $subnet_id2_state"

#Create Route Table
route_table_count_init=$(aws ec2 describe-route-tables --query "length(RouteTables[])")

echo "**************Creating ROUTE TABLE**************"
route_table_id=$(aws ec2 create-route-table --vpc-id $vpc_id --query RouteTable.RouteTableId --output text)
while true;
do
        if [ ${#route_table_id} -gt 0 ]
        then
                break
        else
		route_table_id=$(aws ec2 describe-route-tables --query RouteTables[?RouteTableId=="'$route_table_id'"].RouteTableId --output text)
                sleep 2
        fi
done
echo "ROUTE TABLE ID - $route_table_id"

#Associate Subnet to Route Table
echo "**************Associating SUBNET with ROUTE TABLE**************"
route_table_assoc_id=$(aws ec2 associate-route-table --route-table-id $route_table_id --subnet-id $subnet_id1 --output text)
while true;
do
	if [ ${#route_table_assoc_id} -gt 0 ]
	then
		break
	else
		route_table_assoc_id=$(aws ec2 describe-route-tables --query RouteTables[].Associations[?RouteTableAssociationId=="'$route_table_assoc_id'"].RouteTableAssociationId --output text)
		sleep 2
	fi
done
echo "ASSOCIATED ROUTE TABLE1 ID - $route_table_assoc_id"

#Associate Subnet2 to Route Table
echo "**************Associating SUBNET2 with ROUTE TABLE**************"
route_table_assoc_id2=$(aws ec2 associate-route-table --route-table-id $route_table_id --subnet-id $subnet_id2 --output text)
while true;
do
	if [ ${#route_table_assoc_id2} -gt 0 ]
	then
		break
	else
		route_table_assoc_id2=$(aws ec2 describe-route-tables --query RouteTables[].Associations[?RouteTableAssociationId=="'$route_table_assoc_id2'"].RouteTableAssociationId --output text)
		sleep 2
	fi
done
echo "ASSOCIATED ROUTE TABLE2 ID - $route_table_assoc_id2"

#Create Routes
echo "**************Creating NEW ROUTES**************"
route_result=$(aws ec2 create-route --route-table-id $route_table_id --destination-cidr-block 0.0.0.0/0 --gateway-id $igw_id --output text)
route_state=$(aws ec2 describe-route-tables --query RouteTables[].Routes[?GatewayId=="'$igw_id'"].State --output text)
while true;
do
	if [ "$route_state" = 'active' ]
	then
		break
	else
		route_state=$(aws ec2 describe-route-tables --query RouteTables[].Routes[?GatewayId=="'$igw_id'"].State --output text)
		sleep 2
	fi
done
echo "CREATE ROUTE RESULT - $route_result"

#Create Security Group
echo "**************Creating SECURITY GROUP**************"
security_group_id=$(aws ec2 create-security-group --description "CLIBastionSG" --group-name "CLIBastionSG" --vpc-id $vpc_id --output text)
while true;
do
	if [ ${#security_group_id} -gt 0 ]
	then
		break
	else
		security_group_id=$(aws ec2 describe-security-groups --query SecurityGroups[?GroupId=="'$security_group_id'"].GroupId --output text)
		sleep 2
	fi
done
echo "SECURITY GROUP ID - $security_group_id"

#Add ssh rules to Security Group
echo "**************Adding rules to Security Group**************"
#IPV4
aws ec2 authorize-security-group-ingress --group-id $security_group_id --protocol tcp --port 22 --cidr 0.0.0.0/0
sleep 3
#IPV6
aws ec2 authorize-security-group-ingress --group-id $security_group_id --ip-permissions IpProtocol=tcp,FromPort=22,ToPort=22,Ipv6Ranges='[{CidrIpv6=::/0}]'
sleep 10

#Add http rules to Security Group
#IPV4
aws ec2 authorize-security-group-ingress --group-id $security_group_id --protocol tcp --port 8080 --cidr 0.0.0.0/0
sleep 3
#IPV6
aws ec2 authorize-security-group-ingress --group-id $security_group_id --ip-permissions IpProtocol=tcp,FromPort=8080,ToPort=8080,Ipv6Ranges='[{CidrIpv6=::/0}]'
sleep 10

#Create Security Group2
echo "**************Creating SECURITY GROUP2**************"
security_group_id2=$(aws ec2 create-security-group --description "CLILoadBalSG" --group-name "CLILoadBalSG" --vpc-id $vpc_id --output text)
while true;
do
	if [ ${#security_group_id2} -gt 0 ]
	then
		break
	else
		security_group_id2=$(aws ec2 describe-security-groups --query SecurityGroups[?GroupId=="'$security_group_id2'"].GroupId --output text)
		sleep 2
	fi
done
echo "SECURITY GROUP ID2 - $security_group_id2"

#Add http rules to Security Group2
#IPV4
aws ec2 authorize-security-group-ingress --group-id $security_group_id2 --protocol tcp --port 80 --cidr 0.0.0.0/0
sleep 3
#IPV6
aws ec2 authorize-security-group-ingress --group-id $security_group_id2 --ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,Ipv6Ranges='[{CidrIpv6=::/0}]'
sleep 10

#Create Key Pair
echo "**************Creating KEY PAIR**************"

#aws keypair target directory
#work_dir="/c/temp/"
work_dir=$1
current_day=$2
dir_path_char="/"
file_prefix="AWSKeyPair_"
#aws keypair extension
file_ext=".pem"
#build aws keypair filename
AWS_KEY_PAIR=$file_prefix$current_day
#build aws keypair file path
AWS_KEY_PAIR_PATH=$work_dir$dir_path_char$AWS_KEY_PAIR$file_ext
#user data
user_data_file="user_data_tomcat.txt"
#user_data_file_path=$work_dir$dir_sep_char$user_data_file
user_data_file_path=$user_data_file

#Not working if the file is in a different directory
#user_data_file_path=$dest_dir$dir_sep_char$user_data_file

echo "$user_data_file_path"
#KEY_PAIR=keypair_sep052019_1

aws ec2 create-key-pair --key-name $AWS_KEY_PAIR --query KeyMaterial --output text > $AWS_KEY_PAIR_PATH
aws ec2 wait key-pair-exists --key-name $AWS_KEY_PAIR
echo "**************AWS KEY PAIR $AWS_KEY_PAIR EXISTS**************"

#Launch EC2 Instance
echo "**************Creating EC2 INSTANCE**************"

instance_id=$(aws ec2 run-instances --image-id ami-009d6802948d06e52 --count 1 --instance-type t2.micro --key-name $AWS_KEY_PAIR \
             --subnet-id $subnet_id1 --security-group-ids $security_group_id --associate-public-ip-address --query Instances[].InstanceId \
			 --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=lab_cli_ec1}]' \
			 --user-data file://$user_data_file_path --output text)

instance_id2=$(aws ec2 run-instances --image-id ami-009d6802948d06e52 --count 1 --instance-type t2.micro --key-name $AWS_KEY_PAIR \
             --subnet-id $subnet_id2 --security-group-ids $security_group_id --associate-public-ip-address --query Instances[].InstanceId \
			 --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=lab_cli_ec2}]' \
			 --user-data file://$user_data_file_path --output text)

aws ec2 wait instance-running --instance-ids $instance_id
echo "**************INSTANCE1 IN RUNNING state**************"
echo "INSTANCE1 ID1 - $instance_id"

aws ec2 wait instance-running --instance-ids $instance_id2
echo "**************INSTANCE1 IN RUNNING state**************"
echo "INSTANCE1 ID2 - $instance_id2"

#Check Instance State
instance_state=$(aws ec2 describe-instances --generate-cli-skeleton output --instance-ids $instance_id --query Reservations[].Instances[].Monitoring.State --output text)
echo "INSTANCE1 STATE - $instance_state"

instance_state2=$(aws ec2 describe-instances --generate-cli-skeleton output --instance-ids $instance_id2 --query Reservations[].Instances[].Monitoring.State --output text)
echo "INSTANCE2 STATE - $instance_state2"

#Get Public Ip
instance_public_ip=$(aws ec2 describe-instances --instance-ids $instance_id --query Reservations[].Instances[].PublicIpAddress --output text)
echo "INSTANCE1 PUBLIC IP - $instance_public_ip"

instance_public_ip2=$(aws ec2 describe-instances --instance-ids $instance_id2 --query Reservations[].Instances[].PublicIpAddress --output text)
echo "INSTANCE2 PUBLIC IP - $instance_public_ip2"

#Connect to Instance
echo "ssh -i $AWS_KEY_PAIR_PATH ec2-user@$instance_public_ip"
echo "ssh -i $AWS_KEY_PAIR_PATH ec2-user@$instance_public_ip2"

#create load balancer
lbarn=$(aws elbv2 create-load-balancer --name lab-cli-lb \
		--subnets $subnet_id1 $subnet_id2 \
        --security-groups $security_group_id2 \
		--query LoadBalancers[*].LoadBalancerArn --output text)
echo "LOAD BALANCER ARN - $lbarn"
aws elbv2 wait load-balancer-available --load-balancer-arns $lbarn
echo "LOAD BALANCER ARN - $lbarn"

#create target group
tgarn=$(aws elbv2 create-target-group --name lab-cli-tg --protocol HTTP \
    --port 80 --target-type instance --vpc-id $vpc_id \
	--query TargetGroups[*].TargetGroupArn --output text)

#create listener	
aws elbv2 create-listener \
    --load-balancer-arn $lbarn \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$tgarn

#register targets
aws elbv2 register-targets \
    --target-group-arn $tgarn \
    --targets Id=$instance_id,Port=8080 Id=$instance_id2,Port=8080

lburl=$(aws elbv2 describe-load-balancers --query LoadBalancers[*].DNSName --output text)
echo "LOAD BALANCER URL"
echo "$lburl"

#tags
#name the vpc
aws ec2 create-tags \
  --resources "$vpc_id" \
  --tags Key=Name,Value="lab_cli_vpc"

#name the internet gateway
aws ec2 create-tags \
  --resources "$igw_id" \
  --tags Key=Name,Value="lab_cli_igw"

#name the subnet
aws ec2 create-tags \
  --resources "$subnet_id1" \
  --tags Key=Name,Value="lab_cli_subnet_1"

#name the subnet
aws ec2 create-tags \
  --resources "$subnet_id2" \
  --tags Key=Name,Value="lab_cli_subnet_2"

#name the route table
aws ec2 create-tags \
  --resources "$route_table_id" \
  --tags Key=Name,Value="lab_cli_route_table"

#name the security group
aws ec2 create-tags \
  --resources "$security_group_id" \
  --tags Key=Name,Value="lab_cli_sg1"

#name the security group 2
aws ec2 create-tags \
  --resources "$security_group_id2" \
  --tags Key=Name,Value="lab_cli_sg2"

#name the ec2 instance 1
aws ec2 create-tags \
  --resources "$instance_id" \
  --tags Key=Name,Value="lab_cli_ec1"
  
#name the ec2 instance 2
aws ec2 create-tags \
  --resources "$instance_id2" \
  --tags Key=Name,Value="lab_cli_ec2"
  
echo "**************EOS**************"