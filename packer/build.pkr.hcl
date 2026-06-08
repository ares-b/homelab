build {
  name    = "ubuntu-k3s"
  sources = ["source.proxmox-iso.ubuntu-k3s"]

  provisioner "shell" {
    execute_command  = "sudo -S env {{ .Vars }} bash {{ .Path }}"
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    scripts = [
      "${path.root}/scripts/base.sh",
      "${path.root}/scripts/network.sh",
      "${path.root}/scripts/security.sh",
      "${path.root}/scripts/k3s-modules.sh",
    ]
  }

  provisioner "shell" {
    execute_command   = "sudo -S env {{ .Vars }} bash {{ .Path }}"
    script            = "${path.root}/scripts/cleanup.sh"
    expect_disconnect = true
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "ZERO_FREE_SPACE=${var.zero_free_space}",
      "BUILD_USER=${var.ssh_build_username}",
    ]
  }
}

build {
  name    = "ubuntu-docker"
  sources = ["source.proxmox-iso.ubuntu-docker"]

  provisioner "shell" {
    execute_command  = "sudo -S env {{ .Vars }} bash {{ .Path }}"
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    scripts = [
      "${path.root}/scripts/base.sh",
      "${path.root}/scripts/docker.sh",
      "${path.root}/scripts/network.sh",
      "${path.root}/scripts/security.sh",
    ]
  }

  provisioner "shell" {
    execute_command   = "sudo -S env {{ .Vars }} bash {{ .Path }}"
    script            = "${path.root}/scripts/cleanup.sh"
    expect_disconnect = true
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "ZERO_FREE_SPACE=${var.zero_free_space}",
      "BUILD_USER=${var.ssh_build_username}",
    ]
  }
}
