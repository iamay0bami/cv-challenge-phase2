variable "grafana_cloud_token" {
  description = "The Access Policy Token for Grafana Cloud"
  type        = string
  sensitive   = true  # This hides the token in your terminal logs
}

variable "aws_region" {
    default = "us-east-1"
}

variable "instance_type" {
    default = "c7i-flex.large"
}

variable "ami_id" {
  # Ubuntu 24.04 LTS AMI for us-east-1
  default = "ami-0ecb62995f68bb549" 
}