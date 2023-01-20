@echo off
rem * This batch file will instantiate an AWS EC2 instance with a reverse proxy
rem *
rem === Clean up before-hand
echo Prepping...
erase key-output.json
erase sg-output.json
erase ec2-output.json
erase instance.json
set DEBUG==0
set MYIP=

rem === Get public IP address either from this computer or as a parameter
echo Getting Public IP Address
if not %1!==! set MYIP=%1
echo %MYIP%
if %DEBUG%==1 pause

if not %MYIP%!==! goto IPisParam
curl -s https://checkip.amazonaws.com > %0.tmp
set /p MYIP=<%0.tmp
echo %MYIP%
if %DEBUG%==1 pause
erase %0.tmp
:IPisParam


rem === Setting region
echo Setting the region
aws configure set region us-west-1
aws configure set cli_pager ""

rem === Get the first VPC id
echo Getting the VPC ID
aws ec2 describe-subnets | jq -r ".Subnets[0] | (.VpcId)" > %0.tmp
set /p VPCID=<%0.tmp
echo %VPCID%
if %DEBUG%==1 pause
erase %0.tmp
 
rem === get Subnet ID
echo Getting Subnet ID
rem eg: %VPCID% vpc-05b7b19c6aea1612b
aws ec2 describe-subnets | jq -r ".Subnets[0] | (.SubnetId)" > %0.tmp
set /p SUBNETID=<%0.tmp
echo %SUBNETID%
if %DEBUG%==1 pause
erase %0.tmp

rem === Create a key pair
echo Creating Key Pair
set MYKEYNAME=proxy-key-pair1
aws ec2 create-key-pair --key-name %MYKEYNAME%  > key-output.json
jq -r ".KeyPairId" key-output.json > %0.tmp
set /p KEYPAIRID=<%0.tmp
echo %KEYPAIRID%
if %DEBUG%==1 pause
erase %0.tmp
rem Create the key.pem file
jq -r ".KeyMaterial" key-output.json > %USERPROFILE%\key.pem

rem === Create a security group
echo Creating a security Group
set MYSECURITYGROUP=reverse-proxy1
aws ec2 create-security-group --group-name %MYSECURITYGROUP% --description reverse-proxy --vpc-id %VPCID% > sg-output.json
jq -r ".GroupId" sg-output.json > %0.tmp
set /p SGGROUPID=<%0.tmp
echo %SGGROUPID%
if %DEBUG%==1 pause
erase %0.tmp

rem === Configure security groups 
echo Configuring security groups
aws ec2 authorize-security-group-ingress --group-id %SGGROUPID% --protocol tcp --port 8000 --cidr %MYIP%/32
aws ec2 authorize-security-group-ingress --group-id %SGGROUPID% --protocol tcp --port 22 --cidr %MYIP%/32
aws ec2 authorize-security-group-ingress --group-id %SGGROUPID%  --protocol tcp --port 80 --cidr 0.0.0.0/0
if %DEBUG%==1 pause

rem === Create the instance 
echo Creating the instance
set MYTAGS="ResourceType=instance,Tags=[{Key=Name,Value=MyProxyName}]"
aws ec2 run-instances --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2 --count 1 --instance-type t2.micro --key-name %MYKEYNAME% --security-group-ids %SGGROUPID% --subnet-id %SUBNETID% --tag-specifications %MYTAGS%  > ec2-output.json
jq -r ".Instances[] | .InstanceId" ec2-output.json> %0.tmp
set /p EC2_ID=<%0.tmp
echo %EC2_ID%
if %DEBUG%==1 pause
erase %0.tmp

rem === Wait for the instance to start
echo Waiting for the instance to start
aws ec2 wait instance-status-ok --instance-ids %EC2_ID%

rem === Get public DNS
echo Getting public DNS
aws ec2 describe-instances --instance-ids  %EC2_ID% > instance.json
jq -r ".Reservations []| .Instances [] | .PublicDnsName" instance.json > %0.tmp
set /p PUB_DNS=<%0.tmp
echo %PUB_DNS%
if %DEBUG%==1 pause
erase %0.tmp

rem === Create the teardown script to run later
echo Creating AWSTeardown.bat
set OUTFILE=AWSTeardown.bat
echo aws ec2 terminate-instances --no-cli-pager --instance-ids %EC2_ID%  > %OUTFILE%
echo rem wait for the instance to terminate  >> %OUTFILE%
echo aws ec2 wait instance-terminated --instance-ids %EC2_ID%  >> %OUTFILE%
echo aws ec2 delete-key-pair --no-cli-pager --key-pair-id %KEYPAIRID%  >> %OUTFILE%
echo aws ec2 delete-security-group --no-cli-pager --group-id %SGGROUPID%  >> %OUTFILE%
echo erase %OUTFILE%  >> %OUTFILE%
echo Run %OUTFILE% to clean up afterward
  
rem === Update server
echo Configuring server
ssh -o StrictHostKeyChecking=no -i %USERPROFILE%\key.pem ec2-user@%PUB_DNS% sudo yum update -y
ssh -i %USERPROFILE%\key.pem ec2-user@%PUB_DNS% sudo yum upgrade -y
rem ssh -i %USERPROFILE%\key.pem ec2-user@%PUB_DNS% sudo amazon-linux-extras install nginx1 -y
ssh -i %USERPROFILE%\key.pem ec2-user@%PUB_DNS% sudo amazon-linux-extras install epel
ssh -i %USERPROFILE%\key.pem ec2-user@%PUB_DNS% sudo amazon-linux-extras enable postgresql14
ssh -i %USERPROFILE%\key.pem ec2-user@%PUB_DNS% sudo yum install pip git -y
ssh -i %USERPROFILE%\key.pem ec2-user@%PUB_DNS% sudo yum install postgresql-server libpq-devel nginx -y

git clone https://github.com/mxmoss/vsg.git
ssh -i %USERPROFILE%\key.pem ec2-user@%PUB_DNS% python3 -m pip install django psycopg2-binary virtualenv

rem configure postgres
rem init db
ssh -i %USERPROFILE%\key.pem ec2-user@%PUB_DNS% sudo postgresql-setup --initdb --unit postgresql
rem add postgres to system startup 
ssh -i %USERPROFILE%\key.pem ec2-user@%PUB_DNS% sudo systemctl start postgresql
ssh -i %USERPROFILE%\key.pem ec2-user@%PUB_DNS% sudo systemctl enable postgresql



if %DEBUG%==1 pause

rem === Open Page in browser
start http://%PUB_DNS%:8000

rem === Start reverse proxy
echo Connecting to server
rem echo ssh -i %USERPROFILE%\key.pem ec2-user@%PUB_DNS%
rem ssh -i %USERPROFILE%\key.pem ec2-user@%PUB_DNS%
echo ssh -i %USERPROFILE%\key.pem  ec2-user@%PUB_DNS%
ssh -i %USERPROFILE%\key.pem  ec2-user@%PUB_DNS%
