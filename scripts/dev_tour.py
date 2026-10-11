"""Builds the Studio tour place: the normal game plus dev/DevTour.* (a camera that glides through preset viewpoints).
Usage: python3 scripts/dev_tour.py <out.rbxl>   (needs rojo on PATH)"""
import json
import os
import subprocess
import sys

root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
project = json.load(open(os.path.join(root, "default.project.json")))
project["name"] = "StealAMemeEggTour"
project["tree"]["StarterPlayer"]["StarterPlayerScripts"]["DevTour"] = {"$path": "dev/DevTour.client.luau"}
project["tree"]["ServerScriptService"]["DevTourServer"] = {"$path": "dev/DevTour.server.luau"}
path = os.path.join(root, "tour.project.json")
json.dump(project, open(path, "w"), indent=2)
try:
    subprocess.run(["rojo", "build", path, "-o", sys.argv[1]], check=True, cwd=root)
finally:
    os.remove(path)
print("built", sys.argv[1])
