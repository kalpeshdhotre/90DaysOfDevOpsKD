variable "common_tags" {
  type = map(string)
  default = {
    Project = "terraweek"
    Owner   = "kalpesh"
  }
}
