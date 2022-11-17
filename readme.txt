# Using aws command line to create an instance of a reverse proxy server 
# from this tutorial: https://earthly.dev/blog/build-your-own-ngrok-clone/

#Requirements:
# AWS CLI - https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install

# jq - sudo yum install jq


#Configuring AWS CLI 
To copy files:
scp -v -i \users\moss\key.pem AWSProxy.sh ec2-user@ec2-54-153-16-57.us-west-1.compute.amazonaws.com:~
#sed -i.bak 's/\r$//' AWSProxy.sh
aws configure 
chmod +x AWSProxy.sh
./AWSProxy.sh 

curl -s https://checkip.amazonaws.com > myip.txt
set /p MYIP=<myip.txt
echo %MYIP%
pause
erase myip.txt

#I had to convert the .pem file to a .ppk file - used PuttyGen for that.
#added a passphrase: asdfasdf 

#aws ec2 describe-instances --instance-ids $EC2_ID

NGINX config
#edit /etc/nginx/nginx.conf
add this line:
server_names_hash_bucket_size 128;

after this line:
default_type        application/octet-stream;
sudo sed -i '/default_type        application\/octet-stream;/a server_names_hash_bucket_size 128;' /etc/nginx/nginx.conf


#Start up the reverse proxy service 
#can this be started and then stopped? or does it need to persist?
#i think it is only used to accept the key pair
ssh -i key.pem -R 8080:localhost:8080 ec2-user@ec2-54-219-44-221.us-west-1.compute.amazonaws.com

#on your local computer, run a python webserver on port 8080
#Do this in a directory with an index.html 
#don't put anything you don't want to share with the world
python -m http.server 8080

#in your web browser, go to the AWS URL. This will show the index.html on your local PC 
http://ec2-54-219-44-221.us-west-1.compute.amazonaws.com/

rem Teardown
rem Teardown
aws ec2 terminate-instances --no-cli-pager --instance-ids %EC2_ID% > null
aws ec2 delete-key-pair --no-cli-pager --key-pair-id %KEYPAIRID%
aws ec2 delete-security-group --no-cli-pager --group-id %SGGROUPID%


