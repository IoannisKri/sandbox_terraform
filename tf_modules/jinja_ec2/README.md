## Description

This template uses jinja together with terraform to create a "fleet" of EC2 instances behind an application load balancer. 
EC2 Logs can be sent to Cloudwatch via a Cloudwatch Agent and an alarm can be triggered based on these logs.
ELB logs should be queryable via Athena.

!Disclaimer: We are using an S3 bucket as a dummy code / artifact repository. The code of the application served by the EC2 instances is picked up from the S3 bucket.


## Usage

From within the EC2 instance created previously, do the following:

### Step 1

Edit input.tfvars.json and add / remove instances. The alarm can also be enabled from there by setting "enable_alarm":"true"

From within terraform folder, execute the jinja script:

```python3 jinja.py```

This script will iterate over the input variables and create the actual main.tf file.

When the main.tf file is in place, initialize terraform:

```terraform init```

Now terraform will create .terraform folder and it will be able to perform the deployment


### Step 2

Create the terraform plan with the resource that are about to be created

```terraform plan --var-file input.tfvars.json```

Observe the terraform plan 


### Step 3 (OPTIONAL)

Prepare the deployment

```terraform apply --var-file input.tfvars.json```

Type yes if the plan displayed before seems right

## Overview

![Deployed Infrastructure](../../images/elb.jpg?raw=true "SSM Infrastructure")

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License
[MIT](https://choosealicense.com/licenses/mit/)