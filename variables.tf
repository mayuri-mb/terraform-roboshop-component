variable "project" {
    default = "roboshop"
}

variable "environment" {
    default = "dev"
}

variable "domain_name" {
    default = "daws-88s.online"
}

variable "component" {
    type = string
}

variable "zone_id" {
    default = "Z0600999D8XNX0JXQIHH"
}

variable "health_check_path" {
    default = "/health"
}

variable "app_version" {
    default = "v3"
}

variable "port_no" {
    default = 8080
}

variable "rule_priority" {
    type = number
}
