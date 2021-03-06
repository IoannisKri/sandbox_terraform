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
    log.info('Using default us-east-1 as region')
else:
    os.environ['REGION']=sys.argv[4]      
    log.info(f'Using non-default {sys.argv[4]} as region')

REGION=os.environ['REGION']    
BUCKET=f"sysops-soa-co2-{RANDOM}"
SSM_PARAMETER_AMI_NAME='/aws/service/ami-amazon-linux-latest/amzn2-ami-kernel-5.10-hvm-x86_64-gp2'
TF_MODULES_DIR='tf_modules'

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
    """The produced file can be used for aws configuration"""
    f=open("config", "w")
    f.write("[default]\r")
    f.write(f"aws_access_key_id={os.environ['AWS_ACCESS_KEY_ID']}\r")
    f.write(f"aws_secret_access_key={os.environ['AWS_SECRET_ACCESS_KEY']}\r")
    f.write(f"region={REGION}\r")
    f.write("output=json")
    f.close()

def create_bucket(bucket_name):
    """Create an S3 bucket in a specified region.
    The bucket will store terraform backends
    """
    log.info('Creating terraform backend bucket')
    s3_client = boto3.client('s3', region_name=REGION)
    kms_client= boto3.client('kms', region_name=REGION)
    key=kms_client.describe_key(KeyId='alias/aws/s3')
    try:
        s3_client.create_bucket(Bucket=bucket_name)
        #Put bucket default encryption with aws default s3 key
        s3_client.put_bucket_encryption(
            Bucket=bucket_name,
            ServerSideEncryptionConfiguration={
            'Rules': [
            {
                'ApplyServerSideEncryptionByDefault': {
                    'SSEAlgorithm': 'aws:kms',
                    'KMSMasterKeyID': key['KeyMetadata']['Arn']
                },
                'BucketKeyEnabled': True
            },
        ]
    })
        #Enable bucket versioning to protect terraform state files    
        s3 = boto3.resource('s3', region_name=REGION)
        bucket_versioning = s3.BucketVersioning(bucket_name)
        bucket_versioning.enable()
    except Exception as e:
        log.error(e)


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
        log.error(e)

   
def store_key(material,name):
    """Create a key that will be used to SSH into instances"""
    log.info('Creating PPK file.')
    if material is not None:
        with open(f'{name}.ppk', 'w') as f:
            f.write(material["KeyMaterial"])    
        log.info('PPK file successfully created.')        
    else:
        log.info('Key material is empty. Nothing to do.')    

def create_instance_profile():
    """The EC2 instance gets its permissions from the instance profile"""
    random_name=RANDOM
    log.info(f'Creating IAM Policy with random name: {random_name}')
    iam = boto3.client('iam')  
    #The role needs to be wide because terraform needs access to all APIs     
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
    log.info('Creating EC2 instance.')
    #Note that userdata is executed as ROOT user.
    #We need to switch to the ec2-user folder otherwise the downloaded code will not be visible
    #It's also helpful to make the folders writable so that terraform init can be executed and write files under the folder
    USERDATA_SCRIPT = '''
#!/bin/bash
# Install terraform
yum install -y yum-utils 
yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
yum -y install terraform
yum -y install git
yum -y install jq
pip3 install jinja2 boto3
cd home/ec2-user
mkdir terraform
aws s3 sync s3://{0}/{1}/ ./terraform
chmod 777 -R terraform
'''.format(BUCKET,TF_MODULES_DIR,'{}')
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
        KeyName=RANDOM,
        TagSpecifications=[
        {
            'ResourceType': 'instance',
            'Tags': [
                {
                    'Key': 'Name',
                    'Value': f'{RANDOM}_terraform'
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
    """Upload a file to an S3 bucket.
    This function is used to upload all code files to an S3 Bucket.
    The files are then downloaded by the EC2 instance on startup"""

    log.info(f'Uploading {file_name} to s3')
    if object_name is None:
        object_name = os.path.basename(file_name)
    # Upload the file
    s3_client = boto3.client('s3')
    try:
        response = s3_client.upload_file(file_name, bucket, object_name)
    except Exception as e:
        log.error(e)
        return False
    return True

def create_tf_backend_file(tf_project):
    """Each project needs a backend file of its own.
    The backend.tf located in this folder gets populated properly and copied to all tf templates
    """
    backend = open("backend.tf", "rt")
    data = backend.read()
    data = data.replace('<BUCKET_NAME>', BUCKET).replace('<KEY_NAME>',tf_project)
    backend.close()
    fin = open(f"../{TF_MODULES_DIR}/{tf_project}/backend.tf", "wt")
    fin.write(data)
    fin.close()

def get_tf_projects(directory):
    """Get a list of folders that corresponds to the terraform templates"""
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
    table='terraform-state'
    client = boto3.client('dynamodb',region_name=REGION)
    try:
        response=client.describe_table(TableName=table)
    except:
        #Try to create it only if it doesnt exist
        response=client.create_table(
        AttributeDefinitions=[{'AttributeName': 'LockID','AttributeType': 'S'}],
        BillingMode='PAY_PER_REQUEST',
        TableName=table,
        KeySchema=[{'AttributeName': 'LockID','KeyType': 'HASH'}]
        )  
    return response

if __name__ == "__main__":
    create_tf_backend_ddb()
    #create_aws_profile()
    create_bucket(BUCKET)
    for k in [RANDOM ]:
        key_response=create_key_pair(k)
        store_key(key_response,k)
    for p in get_tf_projects(f'../{TF_MODULES_DIR}'):
        create_tf_backend_file(p)
    for f in getListOfFiles(f'../{TF_MODULES_DIR}'):
        upload_file(f,BUCKET,f[3:])
    sg_id=create_sg()
    ami_id=get_ami()
    instance_profile=create_instance_profile()
    instance_id=create_terraform_ec2(sg_id,instance_profile,ami_id)

