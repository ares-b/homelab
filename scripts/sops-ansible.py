import os
import subprocess
import sys
import tempfile

import yaml

if len(sys.argv) < 4:
    sys.exit(f"usage: {sys.argv[0]} <yaml-file> <section> <cmd> [args...]")

yaml_file, section, *cmd = sys.argv[1:]

with open(yaml_file) as f:
    config = yaml.safe_load(f) or {}

data = {**config.get("common", {}), **config.get(section, {})}

with tempfile.NamedTemporaryFile(mode="w", suffix=".yml", delete=False) as f:
    yaml.dump(data, f)
    tmp = f.name

try:
    resolved = [c.replace("@{section_vars}", "@" + tmp) for c in cmd]
    sys.exit(subprocess.run(resolved).returncode)
finally:
    os.unlink(tmp)
