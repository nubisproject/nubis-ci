output "elb" {
    value = "http://${aws_elb.jenkins.dns_name}/"
}
