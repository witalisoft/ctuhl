provider "vault" {
}

resource "vault_mount" "host-ssh" {
  path        = "host-ssh"
  type        = "ssh"
  description = "host CA"
}

resource "vault_ssh_secret_backend_role" "host-ssh_role" {
    name                    = "host-ssh"
    backend                 = vault_mount.host-ssh.path
    key_type                = "ca"
    allow_host_certificates = true
    allow_user_certificates = false
}