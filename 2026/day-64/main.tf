# main.tf
provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "day64-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  tags       = { Name = "day64-subnet" }
}

resource "aws_instance" "web" {
  ami           = "ami-01a00762f46d584a1" # Amazon Linux 2023, ap-south-1 — verify current AMI
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public.id
  tags          = { Name = "day64-instance", Env = "dev" }
}

resource "aws_s3_bucket" "logs_bucket" {
  bucket = "terraweek-import-test-kalpeshdhotre"
}
