terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.33.0"
    }
  }

backend "s3" {
    bucket         = "remote-state-daws88s-dev" # change this to your bucket name 
    key            = "roboshop-dev-catalogue"   #key should be unique 
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}  

provider "aws" {
  region = "us-east-1"
}
