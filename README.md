# Spotify API - Serverless Data Pipeline with AWS and GitHub Actions
![Python](https://img.shields.io/badge/python-35c4cb?style=for-the-badge&logo=python&logoColor=black&logoSize=auto)
![AWS](https://img.shields.io/badge/AWS-purple?style=for-the-badge&logo=amazonwebservices&logoColor=black&logoSize=auto)
![GitHubActions](https://img.shields.io/badge/Github%20Actions-blue?style=for-the-badge&logo=githubactions&logoColor=black&logoSize=auto)
![Terraform](https://img.shields.io/badge/Terraform-623CE4?style=for-the-badge&logo=terraform&logoColor=black&logoSize=auto)

This is my study project focused on learning data engineering stack on **AWS** and creating simple CI/CD workflow with **Github Actions**. 


## Project overview
![Project diagram](/img/diagram.png)
This project utilizes AWS services to automate data extraction from Spotify API, storing the results in CSV format within an S3 bucket for downstream consumption. The infrastructure is managed using **Terraform**, which provisions and maintains the required AWS resources.
- **GitHub Actions** handles CI/CD, deploying the AWS Lambda function to AWS. When you update/push the code, it will automatically deploy on Lambda
- **AWS EventBridge** schedules Lambda to trigger at specified intervals.
- **AWS Lambda** executes the data extraction by calling the Spotify API, processes the data into CSV format, and uploads the file to AWS S3 for storage.
- **AWS CloudWatch** provides logging and monitoring, capturing Lambda execution logs for error tracking and performance monitoring.

→ This setup ensures that data is automatically fetched, processed, and stored in S3, providing a scalable and serverless data pipeline.


## Prerequisites and Installation
### Prerequisites
- A [Spotify account](https://developer.spotify.com/documentation/web-api/tutorials/getting-started) to access the API
- An AWS account with needed permissions
- Terraform already installed on your machine
## Installation
1. **Fork** this repository
2. Create your AWS environemnt variables for GitHub Actions:
Settings → Secrets and variables → Create your variables
```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
``` 
3. **Clone** the forked repository to your machine
4. Create `/terraform/variable.tf` to store Terraform variables
```
variable "aws_access_key" {
    default = "youracesskey" 
}
variable "aws_secret_key" {
    default = "yoursecretkey"
}
variable "aws_region" {
    default = "yourregion"
}
variable "spotify_client_id" {
    default = "yourclientid"
}
variable "spotify_client_secret" {
    default = "yourclientsecret"
}
```
5. Initialize Terraform
```
cd terraform
terraform init
terraform apply
```
When completed, all components of the pipeline will be setup on AWS and the application will run based on the schedule in the configuration.


## Configuration
### Install additional dependencies
If you want to import additional packages to Lambda function, you have to install them through [Lambda layers](https://docs.aws.amazon.com/lambda/latest/dg/chapter-layers.html).

1. Create layers for Lambda
```
pip install <package_name> -t python/lib/python3.x/site-packages
```
The zipped dependencies must be contained in the exact directory or Lambda will fail to recognize it as a package:
```
python/lib/python3.x/site-packages/<your_dependencies>
```  
2. After create the zipped package, you can manually upload this to a S3 bucket then add this as a layer on Lambda. Or you can create another **aws_lambda_layer_version** resource in Terraform.
### Execute schedule
To customize the Lambda execution schedule, edit the `schedule_expression` parameter of `aws_cloudwatch_event_rule` resource in `main.tf`. By default, the function is set to run at 8:00 AM every day:
```
resource "aws_cloudwatch_event_rule" "lambda_schedule" {
    name = "spotify-schedule"
    description = "Triggers the API once everyday"
    schedule_expression = "cron(0 8 * * ? *)" 
}
```