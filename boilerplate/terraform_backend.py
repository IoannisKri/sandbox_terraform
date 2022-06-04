import json
import boto3
import logging
import time
import os
import sys
import random
import string
from datetime import date

logging.basicConfig(level=os.environ.get("LOGLEVEL", "INFO"))
log = logging.getLogger(__name__)

os.environ['AWS_ACCESS_KEY_ID']=sys.argv[1]
os.environ['AWS_SECRET_ACCESS_KEY']=sys.argv[2]
RANDOM=sys.argv[3]

if len(sys.argv)==4:
    os.environ['REGION']='us-east-1'
    print('Using default us-east-1 as region')
else:
    os.environ['REGION']=sys.argv[4]      
    print(f'Using non-default {sys.argv[4]} as region')

REGION=os.environ['REGION']    
BUCKET=f"ioannis-sysops-soa-co2-{RANDOM}"
SSM_PARAMETER_AMI_NAME='/aws/service/ami-amazon-linux-latest/amzn2-ami-kernel-5.10-hvm-x86_64-gp2'

def get_ami():
    """We need to retrieve the AMI id which will be used to create an Ec2 instance"""
    client = boto3.client('ssm',region_name=REGION)
    #parameter = ssm.get_parameters_by_path(Path='/aws/service/ami-amazon-linux-latest')
    paginator = client.get_paginator('get_parameters_by_path')
    response_iterator = paginator.paginate(
        Path='/aws/service/ami-amazon-linux-latest'
    )
    parameters=[]
    for page in response_iterator:
        for entry in page['Parameters']:
            if entry['Name']==SSM_PARAMETER_AMI_NAME:
                return entry['Value']

def create_aws_profile():
    f=open("config", "w")
    f.write("[default]\r")
    f.write(f"aws_access_key_id={os.environ['AWS_ACCESS_KEY_ID']}\r")
    f.write(f"aws_secret_access_key={os.environ['AWS_SECRET_ACCESS_KEY']}\r")
    f.write(f"region={REGION}\r")
    f.write("output=json")
    f.close()

def create_bucket(bucket_name):
    """Create an S3 bucket in a specified region"""
    log.info('Creating terraform backend bucket')
    s3_client = boto3.client('s3', region_name=REGION)
    try:
        
        s3_client.create_bucket(Bucket=bucket_name)
    except ClientError as e:
        logging.error(e)


def create_key_pair(key_name):
    """Create a key pair that will be used to ssh into instances"""
    client = boto3.client('ec2',region_name=REGION)
    try:
        response=client.create_key_pair(
    KeyName=key_name,
    KeyType='rsa',
    KeyFormat='ppk'
) 
        return response
    except Exception as e:
        logging.error(e)

   
def store_key(material):
    logging.info('Creating PPK file.')
    if material is not None:
        today = date.today()
        with open(f'{today}.ppk', 'w') as f:
            f.write(material["KeyMaterial"])    
        logging.info('PPK file successfully created.')        
    else:
        logging.info('Key material is empty. Nothing to do.')    

def create_instance_profile():
    """The EC2 instance gets its permissions from the instance profile"""
    random_name=RANDOM
    log.info(f'Creating IAM Policy with random name: {random_name}')
    iam = boto3.client('iam')       
    terraform_policy = {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "*",
            "Resource": "*"
        }
    ]
    }
    response = iam.create_policy(PolicyName=random_name, PolicyDocument=json.dumps(terraform_policy))    
    log.info('Wait a little until IAM does its magic')
    policy_arn=response['Policy']['Arn']
    #IAM needs some time to propagate permissions. Wait for some time to avoid permission pitfalls
    time.sleep(10)       
    log.info(response)
    assumed_policy={
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": { "Service": "ec2.amazonaws.com"},
        "Action": "sts:AssumeRole"
        }
    ]
    }
    log.info(f'Creating IAM Role with random name: {random_name}')
    response=iam.create_role(RoleName=random_name, AssumeRolePolicyDocument=json.dumps(assumed_policy))
    log.info(response)
    log.info(f'Creating Instance Profile with random name: {random_name}')
    response=iam.create_instance_profile(InstanceProfileName=random_name)
    log.info(response)
    iam.add_role_to_instance_profile(InstanceProfileName=random_name,RoleName=random_name)
    log.info('IAM Role and EC2 instance profile created successfully')
    log.info('Wait a little until IAM does its magic')
    time.sleep(10)
    iam.attach_role_policy(RoleName=random_name, PolicyArn=policy_arn)
    return random_name


def create_terraform_ec2(sg_id,instance_profile,ami_id):
    """Create an EC2 instance that will be used for terraform deployments"""
    logging.info('Creating EC2 instance.')
    #Note that userdata is executed as ROOT user.
    #We need to switch to the ec2-user folder otherwise the downloaded code will not be visible
    USERDATA_SCRIPT = '''
#!/bin/bash
# Install terraform
yum install -y yum-utils 
yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
yum -y install terraform
yum -y install git
yum -y install jq
cd home/ec2-user
aws s3 sync s3://{0}/tf_modules/ .
'''.format(BUCKET)
    iamInstanceProfile = {
        'Name': instance_profile
    }        
    ec2 = boto3.resource('ec2',region_name=REGION)
    instance = ec2.create_instances(
        ImageId=ami_id,
        UserData=USERDATA_SCRIPT,
        IamInstanceProfile=iamInstanceProfile, 
        SecurityGroupIds=[sg_id],
        MinCount=1,
        MaxCount=1,
        InstanceType="t2.micro",
        KeyName="ioannis",
        TagSpecifications=[
        {
            'ResourceType': 'instance',
            'Tags': [
                {
                    'Key': 'Name',
                    'Value': 'ioannis_terraform'
                } 
            ]
        }]
    )    
    log.info(f"Created EC2 instance: {instance[0].id}")
    return instance[0].id

def create_sg():
    """We need a security group that allows SSH access to the instance"""
    log.info('Creating security group.')
    ec2 = boto3.client('ec2',region_name=REGION)
    #Get default VPC identifier
    response = ec2.describe_vpcs()
    vpc_id = response.get('Vpcs', [{}])[0].get('VpcId', '')
    
    try:
        response = ec2.create_security_group(GroupName=RANDOM,
                                            Description='Allow me to connect via SSH',
                                            VpcId=vpc_id)
        security_group_id = response['GroupId']
        log.info('Security Group Created %s in vpc %s.' % (security_group_id, vpc_id))
        #We need to be able to SSH into the instance. Security group allows the world to connect to port 22
        data = ec2.authorize_security_group_ingress(
            GroupId=security_group_id,
            IpPermissions=[
                  {'IpProtocol': 'tcp',
                'FromPort': 22,
                'ToPort': 22,
                'IpRanges': [{'CidrIp': '0.0.0.0/0'}]}
            ])
        log.info('Ingress Successfully Set %s' % data)
        return security_group_id
    except Exception as e:
        log.error(e)

def upload_file(file_name, bucket, object_name=None):
    """Upload a file to an S3 bucket"""
    log.info(f'Uploading {file_name} to s3')
    # If S3 object_name was not specified, use file_name
    if object_name is None:
        object_name = os.path.basename(file_name)
    # Upload the file
    s3_client = boto3.client('s3')
    try:
        response = s3_client.upload_file(file_name, bucket, object_name)
    except Exception as e:
        logging.error(e)
        return False
    return True

def create_tf_backend_file(tf_project):
    """Each project needs a backend file of its own"""
    #read input file
    backend = open("backend.tf", "rt")
    #read file contents to string
    data = backend.read()
    #replace all occurrences of the required string
    data = data.replace('<BUCKET_NAME>', BUCKET).replace('<KEY_NAME>',tf_project)
    #close the input file
    backend.close()
    #open the input file in write mode
    fin = open(f"../tf_modules/{tf_project}/backend.tf", "wt")
    #overrite the input file with the resulting data
    fin.write(data)
    #close the file
    fin.close()

def get_tf_projects(directory):
    
    projects=next(os.walk(directory))[1]             
    return projects

def getListOfFiles(dirName):
    """Return a list of all nested files under the given directory name"""

    # create a list of file and sub directories 
    # names in the given directory 
    listOfFile = os.listdir(dirName)
    allFiles = []
    # Iterate over all the entries
    for entry in listOfFile:
        # Create full path
        fullPath = os.path.join(dirName, entry)
        # If entry is a directory then get the list of files in this directory 
        if os.path.isdir(fullPath):
            allFiles = allFiles + getListOfFiles(fullPath)
        else:
            allFiles.append(fullPath.replace('\\','/'))
                
    return allFiles


def create_tf_backend_ddb():
    """Create a dynamodb table to store terraform lock ids"""
    client = boto3.client('dynamodb',region_name=REGION)

    response=client.create_table(
    AttributeDefinitions=[
        {
            'AttributeName': 'LockID',
            'AttributeType': 'S'
        },
    ],
        BillingMode='PAY_PER_REQUEST',

    TableName='terraform-state',
    KeySchema=[
        {
            'AttributeName': 'LockID',
            'KeyType': 'HASH' 
        },
    ]) 
    return response

if __name__ == "__main__":
        
    #    create_tf_backend_ddb()
    create_aws_profile()
    create_bucket(BUCKET)
    key_response=create_key_pair('ioannis')
    store_key(key_response)
    for p in get_tf_projects('../tf_modules'):
        create_tf_backend_file(p)
    for f in getListOfFiles('../tf_modules'):
        upload_file(f,BUCKET,f[3:])
    sg_id=create_sg()
    ami_id=get_ami()
    instance_profile=create_instance_profile()
    instance_id=create_terraform_ec2(sg_id,instance_profile,ami_id)
    
    