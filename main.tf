provider "aws" {
  region = var.region
}

# Create a unique S3 bucket for templates
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "template_bucket" {
  bucket = "service-catalog-templates-${random_id.bucket_suffix.hex}"
  acl    = "private"
}

## 1. Create Service Catalog Portfolio
resource "aws_servicecatalog_portfolio" "web_app_portfolio" {
  name          = "WebApplicationPortfolio"
  description   = "Portfolio for web application products"
  provider_name = "IT Department"
}

## 2. Create IAM Role for Launch Constraints
resource "aws_iam_role" "launch_constraint_role" {
  name = "SCWebAppLaunchRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "servicecatalog.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "launch_constraint_policy" {
  role       = aws_iam_role.launch_constraint_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

## 3. Create CloudFormation Template for Web App
data "template_file" "web_app_template" {
  template = file("${path.module}/ec2_instance-cft.yaml")
}

# Updated to use aws_s3_object instead of deprecated aws_s3_bucket_object
resource "aws_s3_object" "web_app_template" {
  bucket  = aws_s3_bucket.template_bucket.bucket
  key     = "templates/ec2_instance-cft.yaml"
  content = data.template_file.web_app_template.rendered
}

## 4. Create Service Catalog Product
resource "aws_servicecatalog_product" "web_app_product" {
  name             = "WebApplicationProduct"
  owner            = "IT Department"
  type             = "CLOUD_FORMATION_TEMPLATE"
  description      = "Web Application with EC2 and ALB"

  provisioning_artifact_parameters {
    description          = "Initial version"
    name                 = "v1.0"
    template_url         = "https://${aws_s3_bucket.template_bucket.bucket_regional_domain_name}/${aws_s3_object.web_app_template.key}"
    type                 = "CLOUD_FORMATION_TEMPLATE"
  }

  tags = {
    "Category" = "WebApplications"
  }
}

## 5. Associate Product with Portfolio
resource "aws_servicecatalog_product_portfolio_association" "web_app_association" {
  portfolio_id = aws_servicecatalog_portfolio.web_app_portfolio.id
  product_id   = aws_servicecatalog_product.web_app_product.id
}

## 6. Add Launch Constraint
resource "aws_servicecatalog_constraint" "web_app_launch_constraint" {
  description  = "Launch constraint for web application"
  portfolio_id = aws_servicecatalog_portfolio.web_app_portfolio.id
  product_id   = aws_servicecatalog_product.web_app_product.id
  type         = "LAUNCH"

  parameters = jsonencode({
    "RoleArn" : aws_iam_role.launch_constraint_role.arn
  })
}

## 7. Grant Access to Users/Groups
resource "aws_servicecatalog_principal_portfolio_association" "developer_access" {
  portfolio_id  = aws_servicecatalog_portfolio.web_app_portfolio.id
  principal_arn = "arn:aws:iam::994466158061:user/Shaik" # Replace with your group
}