terraform {
  backend "s3" {
    bucket         = "gpu-lotto-tfstate"
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "gpu-lotto-tflock"
    encrypt        = true
  }
}
