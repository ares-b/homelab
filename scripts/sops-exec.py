import json
import os
import subprocess
import sys

import yaml

if len(sys.argv) < 4:
    sys.exit(f"usage: {sys.argv[0]} <yaml-file> <VAR_PREFIX> <cmd> [args...]")

yaml_file, prefix, *cmd = sys.argv[1], sys.argv[2], sys.argv[3:]

with open(yaml_file) as f:
    data = yaml.safe_load(f) or {}

env = os.environ.copy()
for k, v in data.items():
    if isinstance(v, (dict, list)):
        env[f"{prefix}{k}"] = json.dumps(v, separators=(",", ":"))
    elif isinstance(v, bool):
        env[f"{prefix}{k}"] = str(v).lower()
    elif v is None:
        env[f"{prefix}{k}"] = ""
    else:
        env[f"{prefix}{k}"] = str(v)

sys.exit(subprocess.run(cmd, env=env).returncode)
