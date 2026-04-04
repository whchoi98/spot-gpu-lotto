provider "aws" {
  alias  = "seoul"
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Project     = "gpu-spot-lotto"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "gpu-spot-lotto"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

provider "aws" {
  alias  = "us_east_2"
  region = "us-east-2"

  default_tags {
    tags = {
      Project     = "gpu-spot-lotto"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"

  default_tags {
    tags = {
      Project     = "gpu-spot-lotto"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
