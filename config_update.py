import os, json, sys

isfile = os.path.isfile
exists = os.path.exists
username = sys.argv[1] if len(sys.argv) == 2 else os.environ.get("SUDO_USER")

if not username:
    print(f"SUDO_USER is empty, need your username manually for the config directory:\n  {sys.argv[0]} <username>")
    sys.exit(1)

ROOT_CFG = "/usr/share/chillpill-shell/config.jsonc.example"
HOME_CFG = f"/home/{username}/.config/chillpill-shell/config.jsonc"

if not isfile(ROOT_CFG):
    print(f"{ROOT_CFG} not found.")
    sys.exit(2)

if not isfile(HOME_CFG):
    print(f"{HOME_CFG} not found.")
    sys.exit(2)

with open(ROOT_CFG, "r") as f:
    root_json_data = json.load(f)

with open(HOME_CFG, "r") as f:
    home_json_data = json.load(f)

merged = root_json_data.copy()
merged.update(home_json_data)

with open(HOME_CFG, "w") as f:
    json.dump(merged, f, indent=2)
