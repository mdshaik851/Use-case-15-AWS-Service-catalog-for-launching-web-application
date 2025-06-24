provider "aws" {
  region = "us-west-1"
}

resource "aws_s3_bucket" "catalog_bucket" {
  bucket        = "service-catalog-webapp-template-bucket-${random_id.suffix.hex}"
  force_destroy = true
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_object" "template" {
  bucket = aws_s3_bucket.catalog_bucket.id
  key    = "template.yaml"
  source = "${path.module}/template.yaml"
  etag   = filemd5("${path.module}/template.yaml")
}

resource "aws_servicecatalog_portfolio" "webapp_portfolio" {
  name          = "WebAppPortfolio"
  description   = "Portfolio for launching web applications"
  provider_name = "IT Admin"
}

resource "aws_servicecatalog_product" "webapp_product" {
  name        = "WebAppProduct"
  owner       = "IT Admin"
  description = "EC2 based web app"

  provisioning_artifact_parameters {
    name         = "v1"
    description  = "Initial version"
    template_url = "https://${aws_s3_bucket.catalog_bucket.bucket}.s3.amazonaws.com/${aws_s3_object.template.key}"
    type         = "CLOUD_FORMATION_TEMPLATE"
  }
}

resource "aws_servicecatalog_portfolio_product_association" "association" {
  portfolio_id = aws_servicecatalog_portfolio.webapp_portfolio.id
  product_id   = aws_servicecatalog_product.webapp_product.id
}


resource "aws_iam_role" "launch_role" {
  name = "ServiceCatalogLaunchRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "servicecatalog.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "launch_policy_attachment" {
  role       = aws_iam_role.launch_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_servicecatalog_launch_role" "launch_role_assoc" {
  portfolio_id = aws_servicecatalog_portfolio.webapp_portfolio.id
  product_id   = aws_servicecatalog_product.webapp_product.id
  role_arn     = aws_iam_role.launch_role.arn
}
