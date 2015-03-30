output "elb" {
    value = "http://${aws_route53_record.ci.name}/"
}
