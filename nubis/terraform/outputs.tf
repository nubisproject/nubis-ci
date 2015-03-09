output "elb" {
    value = "http://${aws_route53_record.jenkins.name}/"
}

output "instance" {
    value = "ubuntu@${aws_instance.jenkins.public_dns}"
}
