variable "admin_email" {
  description = "Email for security alerts"
  type        = string
  default     = "admin@example.com"
}

variable "inactive_user_days" {
  description = "Days before user is considered inactive"
  type        = number
  default     = 90
}
