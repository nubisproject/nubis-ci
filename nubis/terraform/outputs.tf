output "iam_role" {
  value = "${join(",",aws_iam_role.ci.*.id)}"
}
