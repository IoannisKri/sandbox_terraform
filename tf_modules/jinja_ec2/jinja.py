from jinja2 import Environment, FileSystemLoader
import json
import boto3

def get_vpc_id():
    ec2 = boto3.resource('ec2', region_name='us-east-1')
    client = boto3.client('ec2', region_name='us-east-1')
    vpcs = list(ec2.vpcs.filter(Filters=[]))
    for vpc in vpcs:
        response = client.describe_vpcs(
        VpcIds=[
            vpc.id,
        ]
    )   
        for v in response['Vpcs']:
            if v[ "IsDefault"]:
                print(f'Using default VPC {v["VpcId"]}')
                return v["VpcId"]

def populate_var_file(vpc_id):
    """Each project needs a backend file of its own.
    The backend.tf located in this folder gets populated properly and copied to all tf templates
    """
    backend = open("./input.tfvars.json", "rt")
    data = backend.read()
    data = data.replace('<VPC_ID>', vpc_id)
    backend.close()
    fin = open(f"./input.tfvars.json", "wt")
    fin.write(data)
    fin.close()

def populate_backend():
    f = open('./input.tfvars.json')
    data = json.load(f)
    file_loader = FileSystemLoader('.')
    env = Environment(loader=file_loader)
    template = env.get_template('main_template')
    output = template.render(instances=data['instances'])
    f = open("main.tf", "w")
    f.write(output)
    f.close()

if __name__ == "__main__":
    vpc_id=get_vpc_id()
    populate_var_file(vpc_id)
    populate_backend()