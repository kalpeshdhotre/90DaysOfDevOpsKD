terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_s3_bucket" "terraweek_bucket" {
  bucket = "terraweek-day-61-kalpeshdhotre-2026"

  tags = {
    Name = "TerraWeek-Day1"
  }
}

resource "aws_instance" "terraweek_instance" {
  ami           = "ami-0f7406a708a43024c" # from the describe-images command above
  instance_type = "t2.micro"

  tags = {
    Name = "TerraWeek-Modified"
  }
}
