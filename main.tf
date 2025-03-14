resource "null_resource" "ensure_files_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/files"
  }
}