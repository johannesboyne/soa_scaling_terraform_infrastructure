variable "aws_region" {
    description = "AWS region to launch servers."
    default = "us-west-1"
}

variable "access_key" {
    description = "AWS access key"
}
variable "secret_key" {
    description = "AWS secret key"
}
variable "registry" {
    description = "Docker registry"
    default = "https://index.docker.io/v1/"
}
variable "auth" {
    description = "Docker auth token"
}
variable "email" {
    description = "Docker email"
}
