aws ec2 terminate-instances --no-cli-pager --instance-ids i-07a4a34bd42e4870f  
rem wait for the instance to terminate  
aws ec2 wait instance-terminated --instance-ids i-07a4a34bd42e4870f  
aws ec2 delete-key-pair --no-cli-pager --key-pair-id key-0356af3782aa61489  
aws ec2 delete-security-group --no-cli-pager --group-id sg-0581bf8720a94549a  
