#!/bin/bash
#echo off
# * This batch file will instantiate an AWS EC2 instance with a reverse proxy
# *
# === Clean up before-hand
echo Prepping...
rm key-output.json;
rm sg-output.json;
rm ec2-output.json;
rm instance.json;
unset $MYIP;
USERPROFILE=~

# === Get public IP address either from this computer or as a parameter
echo Getting Public IP Address;
if [ -n "$1" ]
then
  MYIP=$1;
else
  curl -s https://checkip.amazonaws.com > $0.tmp;
  MYIP=$(cat $0.tmp);
 rm $0.tmp;
fi
echo $MYIP;
sleep 5;

# === Setting region
echo Setting the region
aws configure set region us-west-1
aws configure set cli_pager ""

# === Get the first VPC id
echo Getting the VPC ID
aws ec2 describe-subnets | jq -r ".Subnets[0] | (.VpcId)" > $0.tmp
VPCID=$(cat $0.tmp)
echo $VPCID
sleep 5
rm $0.tmp
 
# === get Subnet ID
echo Getting Subnet ID
# eg: $VPCID vpc-05b7b19c6aea1612b
aws ec2 describe-subnets | jq -r ".Subnets[0] | (.SubnetId)" > $0.tmp
SUBNETID=$(cat $0.tmp)
echo $SUBNETID
sleep 5
rm $0.tmp

# === Create a key pair
echo Creating Key Pair
MYKEYNAME="proxy-key-pair2"
aws ec2 create-key-pair --key-name $MYKEYNAME  > key-output.json
jq -r ".KeyPairId" key-output.json > $0.tmp
KEYPAIRID=$(cat $0.tmp)
echo $KEYPAIRID
sleep 5
rm $0.tmp
# Create the key.pem file
jq -r ".KeyMaterial" key-output.json > $USERPROFILE\key.pem

# === Create a security group
echo Creating a security Group
MYSECURITYGROUP="reverse-proxy2"
aws ec2 create-security-group --group-name $MYSECURITYGROUP --description reverse-proxy2 --vpc-id $VPCID > sg-output.json
jq -r ".GroupId" sg-output.json > $0.tmp
SGGROUPID=$(cat $0.tmp)
echo $SGGROUPID
sleep 5
rm $0.tmp

# === Configure security groups 
echo Configuring security groups
aws ec2 authorize-security-group-ingress --group-id $SGGROUPID --protocol tcp --port 22 --cidr $MYIP/32
aws ec2 authorize-security-group-ingress --group-id $SGGROUPID  --protocol tcp --port 80 --cidr 0.0.0.0/0
sleep 5

# === Create the instance 
echo Creating the instance
MYTAGS="ResourceType=instance,Tags=[{Key=Name,Value=ProxyOnDemandName}]"
aws ec2 run-instances --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2 --count 1 --instance-type t2.micro --key-name $MYKEYNAME --security-group-ids $SGGROUPID --subnet-id $SUBNETID --tag-specifications $MYTAGS > ec2-output.json
jq -r ".Instances[] | .InstanceId" ec2-output.json> $0.tmp
EC2_ID=$(cat $0.tmp)
echo $EC2_ID
sleep 5
rm $0.tmp

# === Wait for the instance to start
echo Waiting for the instance to start
aws ec2 wait instance-status-ok --instance-ids $EC2_ID

# === Get public DNS
echo Getting public DNS
aws ec2 describe-instances --instance-ids  $EC2_ID > instance.json
jq -r ".Reservations []| .Instances [] | .PublicDnsName" instance.json > $0.tmp
PUB_DNS=$(cat $0.tmp)
echo $PUB_DNS
sleep 5
rm $0.tmp

# === Create the teardown script to run later
echo Creating AWSTeardown.sh                                                                                            
OUTFILE="AWSTeardown.sh"
echo $OUTFILE
echo "#!/bin/bash" > $OUTFILE
echo "aws ec2 terminate-instances --instance-ids $EC2_ID"  >> $OUTFILE
echo "# wait for the instance to terminate"  >> $OUTFILE
echo "aws ec2 wait instance-terminated --instance-ids $EC2_ID"  >> $OUTFILE
echo "aws ec2 delete-key-pair --key-pair-id $KEYPAIRID"  >> $OUTFILE
echo "aws ec2 delete-security-group --group-id $SGGROUPID"  >> $OUTFILE
echo Run AWSTeardown.sh to clean up afterward
  
# === create /etc/nginx/conf.d/server.conf
echo Creating server.conf
OUTFILE="server.conf"
echo "upstream tunnel {	"	> $OUTFILE
echo "  server 127.0.0.1:8080;	"	>> $OUTFILE
echo "}	"		>> $OUTFILE
echo "server {	"	>> $OUTFILE
echo "  server_name $PUB_DNS;"	>> $OUTFILE
echo "  location / {"	>> $OUTFILE
echo "    proxy_set_header X-Real-IP $remote_addr;	"		>> $OUTFILE
echo "    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;	" >> $OUTFILE
echo "    proxy_set_header Host $http_host;"	>> $OUTFILE
echo "    proxy_redirect off;	"		>> $OUTFILE
echo "    proxy_pass http://tunnel;	"	>> $OUTFILE
echo "  }	"	>> $OUTFILE
echo "}	"		>> $OUTFILE
sleep 5

# === Update server
echo Configuring server
ssh -o StrictHostKeyChecking=no -i $USERPROFILE\key.pem ec2-user@$PUB_DNS sudo yum update -y
ssh -i $USERPROFILE\key.pem ec2-user@$PUB_DNS sudo amazon-linux-extras install nginx1 -y
scp -v -i $USERPROFILE\key.pem server.conf ec2-user@$PUB_DNS:/tmp
ssh -i $USERPROFILE\key.pem ec2-user@$PUB_DNS sudo sed -i '/octet-stream;/a \\tserver_names_hash_bucket_size 128;' /etc/nginx/nginx.conf
ssh -i $USERPROFILE\key.pem ec2-user@$PUB_DNS sudo mv /tmp/server.conf /etc/nginx/conf.d/
ssh -i $USERPROFILE\key.pem ec2-user@$PUB_DNS sudo service nginx start
sleep 5

# === Open Page in browser
# start http://$PUB_DNS

# === Start reverse proxy
echo Starting Rverse Proxy
ssh -i $USERPROFILE\key.pem -R 8080:localhost:8080 ec2-user@$PUB_DNS
