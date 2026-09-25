#!/usr/bin/env python3
"""Build-time validation of input/vive_controller_profile.json.

Called by the check_profile_json CMake target. Exits non-zero with an
ERROR: message on the first problem found.
"""
import json
import os
import sys


def main() -> int:
    profile_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), os.pardir, "input", "vive_controller_profile.json"
    )
    with open(profile_path) as f:
        data = json.load(f)

    if data.get("jsonid") != "input_profile":
        print("ERROR: jsonid must be input_profile", file=sys.stderr)
        return 1
    if data.get("controller_type") != "vive_controller":
        print("ERROR: controller_type must be vive_controller", file=sys.stderr)
        return 1
    if data.get("input_bindingui_mode") != "controller_handed":
        print("ERROR: input_bindingui_mode must be controller_handed", file=sys.stderr)
        return 1

    sources = data.get("input_source", {})
    required = [
        "/input/system",
        "/input/application_menu",
        "/input/grip",
        "/input/trigger",
        "/input/trackpad",
        "/output/haptic",
    ]
    for req in required:
        if req not in sources:
            print(f"ERROR: Missing required input source: {req}", file=sys.stderr)
            return 1

    print("Profile JSON validation passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
