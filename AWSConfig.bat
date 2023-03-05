@echo on
echo Configuring server
ssh -o StrictHostKeyChecking=no -i %KEYPEM% %CREDENTIAL% sudo yum update -y
ssh -i %KEYPEM% %CREDENTIAL% sudo yum upgrade -y

rem == Configure server to run django + postgres
rem ssh -i %KEYPEM% %CREDENTIAL% sudo amazon-linux-extras install nginx1 -y
ssh -i %KEYPEM% %CREDENTIAL% sudo amazon-linux-extras install epel
ssh -i %KEYPEM% %CREDENTIAL% sudo amazon-linux-extras enable postgresql14
ssh -i %KEYPEM% %CREDENTIAL% sudo yum install pip git jq -y
ssh -i %KEYPEM% %CREDENTIAL% sudo yum install postgresql-server libpq-devel nginx -y
ssh -i %KEYPEM% %CREDENTIAL% sudo yum update -y
ssh -i %KEYPEM% %CREDENTIAL% python3 -m pip install django psycopg2-binary virtualenv

rem configure postgres
rem init db
ssh -i %KEYPEM% %CREDENTIAL% sudo postgresql-setup --initdb --unit postgresql
rem add postgres to system startup 
ssh -i %KEYPEM% %CREDENTIAL% sudo systemctl start postgresql
ssh -i %KEYPEM% %CREDENTIAL% sudo systemctl enable postgresql

ssh -i %KEYPEM% %CREDENTIAL% sudo git clone https://github.com/mxmoss/vsg.git
ssh -i %KEYPEM% %CREDENTIAL% sudo chmod +x ~/vsg/vsgSite/vsgSite/static/AWSProxy.sh
rem ssh -i %KEYPEM% %CREDENTIAL% sudo chmod 700 /root/key.pem 

if %DEBUG%==1 pause

rem === Open Page in browser
start http://%PUB_DNS%:8000

rem === Connecting to server
echo Connecting to server
echo ssh -i %KEYPEM%  %CREDENTIAL% > startme.txt
ssh -i %KEYPEM%  %CREDENTIAL%
