variable "instance" {
}
variable "vpc_id" {
}

variable "key" {
#We cand provide default values that will be used if the given input variables are not rovided
#default     = "willy"
#We cand provide the variable type
type        = string
#A description helps understand the meaning of the variable
description = "The key name that will be used to connect to the instance"
#We can validate the provided inputs to avoid mistakes
validation {
    condition     = length(var.key) > 2
    error_message = "The key name ${var.key} is not longer than 2 characters."
}
}
