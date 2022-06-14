## Description

- Deploy a simple EC2 instance with a proper security group and instance profile. The instance exposes a simple web page.
- The instance is reachable via Internet. The predefined VPC infrastructure that comes with the sandbox account has been used.
- The user is able to connect to the EC2 instance via SSH.

## Usage

From within the Terraform EC2 instance created previously, do the following:

### Step 1

From within terraform folder, initialize terraform:

```terraform init```

Now terraform will create .terraform folder and it will be able to perform the deployment

### Step 2

Create the terraform plan with the resource that are about to be created

```terraform plan --var-file input.tfvars```

Observe the terraform plan 


### Step 3 (OPTIONAL)

Prepare the deployment

```terraform apply --var-file input.tfvars```

Type yes if the plan displayed before seems right

## Overview

![Deployed Infrastructure](../../images/simple_ec2.png?raw=true "SSM Infrastructure")

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License
[MIT](https://choosealicense.com/licenses/mit/)