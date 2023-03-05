@echo off
rem * This batch file will instantiate an AWS EC2 instance
rem *
rem Usage: AWSInstance <instance #> <django Y> <ip address> 
rem === Clean up before-hand
echo Prepping...
erase key-output.json
erase sg-output.json
erase ec2-output.json
erase instance.json
set DEBUG=0
set MYIP=
set INCLUDEDJANGO=
set MYREGION=region us-west-1

set MYINST=%1
if %1!==! set MYINST=1
set MYKEYNAME=proxy-key-pair%MYINST%
set MYSECURITYGROUP=reverse-proxy%MYINST%

rem === Include Django?
if not %2!==! set INCLUDEDJANGO=1

rem === Get public IP address either from this computer or as a parameter
echo Getting Public IP Address
if not %3!==! set MYIP=%3
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
aws configure set %MYREGION%
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
aws ec2 create-key-pair --key-name %MYKEYNAME%  > key-output.json
jq -r ".KeyPairId" key-output.json > %0.tmp
set /p KEYPAIRID=<%0.tmp
echo %KEYPAIRID%
if %DEBUG%==1 pause
erase %0.tmp
rem Create the key.pem file
set KEYPEM=%USERPROFILE%\key%MYINST%.pem
jq -r ".KeyMaterial" key-output.json > %KEYPEM%

rem === Create a security group
echo Creating a security Group
aws ec2 create-security-group --group-name %MYSECURITYGROUP% --description reverse-proxy --vpc-id %VPCID% > sg-output.json
jq -r ".GroupId" sg-output.json > %0.tmp
set /p SGGROUPID=<%0.tmp
echo %SGGROUPID%
if %DEBUG%==1 pause
erase %0.tmp

rem === Configure security group 
echo Configuring security group
aws ec2 authorize-security-group-ingress --group-id %SGGROUPID% --protocol tcp --port 80   --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id %SGGROUPID% --protocol tcp --port 22   --cidr %MYIP%/32
aws ec2 authorize-security-group-ingress --group-id %SGGROUPID% --protocol tcp --port 3389 --cidr %MYIP%/32
aws ec2 authorize-security-group-ingress --group-id %SGGROUPID% --protocol tcp --port 8000 --cidr %MYIP%/32
if %DEBUG%==1 pause

rem === Create the instance 
echo Creating the instance
set MYTAGS="ResourceType=instance,Tags=[{Key=Name,Value=my_instance_%MYINST%}]"
echo %MYTAGS%
if %DEBUG%==1 pause
rem aws ec2 run-instances --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2 --count 1 --instance-type t2.micro --key-name %MYKEYNAME% --security-group-ids %SGGROUPID% --subnet-id %SUBNETID% --tag-specifications %MYTAGS%  > ec2-output.json
aws ec2 run-instances --image-id resolve:ssm:/aws/service/ami-windows-latest/Windows_Server-2016-English-Full-Base --count 1 --instance-type t2.micro --key-name %MYKEYNAME% --security-group-ids %SGGROUPID% --subnet-id %SUBNETID% --tag-specifications %MYTAGS%  > ec2-output.json
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
set CREDENTIAL=ec2-user@%PUB_DNS%
if %DEBUG%==1 pause
erase %0.tmp

rem === Create the teardown script to run later
echo Creating AWSTeardown%MYINST%.bat
set OUTFILE=AWSTeardown%MYINST%.bat
echo aws ec2 terminate-instances --no-cli-pager --instance-ids %EC2_ID%  > %OUTFILE%
echo rem wait for the instance to terminate  >> %OUTFILE%
echo aws ec2 wait instance-terminated --instance-ids %EC2_ID%  >> %OUTFILE%
echo aws ec2 delete-key-pair --no-cli-pager --key-pair-id %KEYPAIRID%  >> %OUTFILE%
echo aws ec2 delete-security-group --no-cli-pager --group-id %SGGROUPID%  >> %OUTFILE%
echo erase %KEYPEM% >> %OUTFILE%
echo erase %OUTFILE%  >> %OUTFILE%
echo Run %OUTFILE% to clean up afterward
  
if not %INCLUDEDJANGO%!==! call AWSConfig.bat
