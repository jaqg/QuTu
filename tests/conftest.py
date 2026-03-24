"""conftest.py — inject hyphen-named scripts as importable module aliases.

The scripts use hyphenated filenames (qutu-parse-output.py etc.) which
Python cannot import with a regular `import` statement.  This conftest
loads them via importlib and registers them under both their real name
and the short alias used throughout the test suite.
"""

import importlib.util
import sys
from pathlib import Path

SCRIPTS = Path(__file__).parent.parent / "scripts"


def _load(filename: str):
    path = SCRIPTS / filename
    name = filename.replace("-", "_").removesuffix(".py")
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod          # register before exec (handles circular refs)
    spec.loader.exec_module(mod)
    return mod


# Load once; register under both the canonical name and the short alias
_po   = _load("qutu-parse-output.py")
sys.modules["parse_output"] = _po

_vis  = _load("qutu-visualize.py")
sys.modules["visualize"] = _vis

_anim = _load("qutu-animate.py")
sys.modules["animate"] = _anim
