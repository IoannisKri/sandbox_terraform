# Prerequisites

putty / puttygen
python boto3 package
Visual Studio Code (or other editor)

## Installation

Use the package manager [pip](https://pip.pypa.io/en/stable/) to install boto3.

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