import sys
from pathlib import Path

# Tests import the scripts as top-level modules (as the scripts do).
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
