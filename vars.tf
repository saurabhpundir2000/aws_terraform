variable aws_reg {
  description = "This is aws region"
  default     = "ap-south-1"
  type        = string
}

variable stack {
  description = "this is name for tags"
  default     = "terraform"
}

variable username {
  description = "DB username"
}

variable password {
  description = "DB password"
}

variable dbname {
  description = "db name"
}

variable ssh_key {
  default     = "EKS.pem"
  description = "Default pub key"
}

variable ssh_priv_key {
  default     = "EKS.pem"
  description = "Default pub key"
}