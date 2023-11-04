# is459-assignment2


## How to set up the project

1. Clone the repository
2. cd `backend/lambda/lambda_layer` directory, and run the following commands:

```
chmod +x build.sh
./build.sh
```
- :memo: **Note:** This can be automated in a CI/CD pipeline, it will create a zip file containing the python dependencies needed for the lambda functions to run, to add more libraries, add them to the requirements.txt file and run the build.sh script again.

3. Under the terraform directory, create a terraform.tfvars file with the following content:

```
AWS_ACCESS_KEY_ID     = "your_aws_access_key_id"
AWS_SECRET_ACCESS_KEY = "your_aws_secret_access_key"
AWS_ACCOUNT_ID        = "your_aws_account_id"
AWS_REGION            = "your_aws_region"
```

4. Run the following commands:

```
cd terraform
terraform init
terraform apply
```

5. After the terraform script is done, you will have to go to the AWS console and configure the Twitter credentials at Secrets Manager.
- :memo: **Note:** An alternative to secrets manager is to pass the secrets via the CI/CD pipeline directly into the environment variables of the lambda functions.
