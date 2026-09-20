output "raw_bucket" {
  value = aws_s3_bucket.raw.id
}
output "processed_bucket" {
  value = aws_s3_bucket.processed.id
}
output "scripts_bucket" {
  value = aws_s3_bucket.scripts.id
}
output "glue_job_name" {
  value = aws_glue_job.customers_etl.name
}
output "glue_role_arn" {
  value = aws_iam_role.glue.arn
}
