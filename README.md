## Description

- This repository uses Terraform to deploy some infrastructure in AWS. The idea behind this, is to quickly deploy working examples in timeboxed sandbox accounts without having to repeat manual steps every time. The sample templates included, cover a small range of AWS tools as well as some useful Terraform examples that can be useful in real world scenarios.

- Terraform is an open-source infrastructure as code software tool created by HashiCorp. Users define and provide data center infrastructure using a declarative configuration language known as HashiCorp Configuration Language, or optionally JSON

Read More about Terraform [here](https://www.terraform.io/).

## Installation and Prerequisites

- putty / puttygen
- Visual Studio Code (or other editor)
- python boto3 package

Use the package manager [pip](https://pip.pypa.io/en/stable/) to install boto3 to your local machine.

```bash
pip install boto3
```

## Usage

### Step 1

From within boilerplate folder, execute the following command:

```python3 terraform_backend.py ACCESS_KEY SECRET_ACCESS_KEY NAME```

Now you have an EC2 instance with terraform installed and some bootstrapped templates ready to be deployed.

![Deployed Infrastructure](images/1_sYfCr4Jlo_6nDmgclWjxVg.png?raw=true "Terraform Backend")

### Step 2

- Retrieve the instance's Public IP
- Connect to the instance via Putty with the mewly generated SSH key

### Step 3 (OPTIONAL)

- Open puttygen and convert key to OpenSSH format.
- Edit ssh/config file and add map the newly created key to the remote instance
- Connect to the instance via VSC Remote Desktop and open the root folder

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License
[MIT](https://choosealicense.com/licenses/mit/)