from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
model = (root / "Ergo/Tabs/Check/LogicEditorModel.swift").read_text()
vocabulary = model[:model.index("struct LogicEditorSymbolDefinition")]
checks = (root / "Checks/LogicEditorChecks.swift").read_text()

with tempfile.TemporaryDirectory(prefix="ergo-logic-checks-") as directory:
    script = Path(directory) / "main.swift"
    script.write_text(vocabulary + checks)
    subprocess.run(["swift", str(script)], check=True)
