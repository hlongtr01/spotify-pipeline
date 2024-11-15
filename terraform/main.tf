provider "aws" {
    access_key = var.aws_access_key
    secret_key = var.aws_secret_key
    region = var.aws_region
}


# CREATE S3 BUCKET FOR STORING DATA AND LAMBDA LAYERS
// Random suffix for naming bucket
resource "random_pet" "bucket_suffix" {
    length = 2
}
// Bucket for storing Lambda layer
resource "aws_s3_bucket" "lambda_bucket" {
    bucket = "spotify-lambda-${random_pet.bucket_suffix.id}"
    force_destroy = true
    tags = {
        Name = "LambdaBucket"
        Environment = "Dev"
    }
}
// Bucket for storing extracted data
resource "aws_s3_bucket" "data_bucket" {
    bucket = "spotify-data-${random_pet.bucket_suffix.id}"
    force_destroy = true
    tags = {
        Name = "DataBucket"
        Environment = "Dev"
    } 
}


# LAMBDA LAYER SETUP
// Upload Lambda layer to S3 
resource "aws_s3_object" "requests_object" {
    bucket = aws_s3_bucket.lambda_bucket.bucket
    key = "python-requests.zip"
    source = "../layer/python-requests.zip"
}
// Create Lambda layer using the file from S3
resource "aws_lambda_layer_version" "requests_layer" {
    layer_name = "python-requests"
    s3_bucket = aws_s3_bucket.lambda_bucket.id
    s3_key = aws_s3_object.requests_object.key
    compatible_runtimes = ["python3.11"]
    lifecycle {
        create_before_destroy = true
    }
}


# LAMBDA SETUP
// Create Lambda function role
resource "aws_iam_role" "lambda_role" {
    name = "lambda_execution_role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Sid = ""
            Principal = {Service = "lambda.amazonaws.com"}
        }]
    })  
}
// Attach execution policy to the role
resource "aws_iam_role_policy_attachment" "lambda_policy" {
    role = aws_iam_role.lambda_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
// Attach S3 access policy to the role
resource "aws_iam_role_policy_attachment" "s3_policy" {
    role = aws_iam_role.lambda_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
// Create initial Lambda function + attach the created role
resource "aws_lambda_function" "spotify_function" {
    function_name = "SpotifyFunction"
    role = aws_iam_role.lambda_role.arn
    handler = "lambda_function.lambda_handler"
    runtime = "python3.11"
    filename = "../layer/lambda_function.zip"
    timeout = 10
    layers = [
        aws_lambda_layer_version.requests_layer.arn,
        "arn:aws:lambda:${var.aws_region}:336392948345:layer:AWSSDKPandas-Python311:17" // Pandas package managed by AWS
    ]
    environment {
        variables = {
            SPOTIFY_CLIENT_ID = var.spotify_client_id
            SPOTIFY_CLIENT_SECRET = var.spotify_client_secret
            S3_BUCKET = aws_s3_bucket.data_bucket.bucket
        }
    }
}


# EVENTBRIDGE SETUP
// Create an EventBridge rule for the schedule
resource "aws_cloudwatch_event_rule" "lambda_schedule" {
    name = "spotify-schedule"
    description = "Triggers the API once everyday"
    schedule_expression = "cron(0 8 * * ? *)"       // Trigger at 8am UTC every day
}
// Add a target for the EventBridge rule to trigger the Lambda function
resource "aws_cloudwatch_event_target" "lambda_target" {
    rule = aws_cloudwatch_event_rule.lambda_schedule.name
    target_id = "lambda_target"
    arn = aws_lambda_function.spotify_function.arn
}
// Add permission for EventBridge
resource "aws_lambda_permission" "eventbridge_allow" {
    statement_id = "AllowEventBridgeInvoke"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.spotify_function.function_name
    principal = "events.amazonaws.com"
    source_arn = aws_cloudwatch_event_rule.lambda_schedule.arn
}