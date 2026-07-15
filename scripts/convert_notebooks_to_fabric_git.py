from __future__ import annotations

import json
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
NOTEBOOK_SOURCE = ROOT / "fabric" / "notebooks"
ITEM_ROOT = ROOT / "workspace-items"

NOTEBOOKS = [
    ("00_generate_raw_data", "Generate deterministic raw Customer 360 demo data in OneLake."),
    ("01_raw_to_silver", "Land Bronze raw tables and create cleansed/joined Silver tables."),
    ("02_silver_to_gold", "Create business-ready Gold tables for the semantic model and report."),
    ("03_run_end_to_end", "Run the full demo pipeline from raw generation through Gold tables."),
]

LOGICAL_IDS = {
    "lh_customer360": "11111111-1111-4111-8111-111111111111",
    "00_generate_raw_data": "22222222-2222-4222-8222-222222222222",
    "01_raw_to_silver": "33333333-3333-4333-8333-333333333333",
    "02_silver_to_gold": "44444444-4444-4444-8444-444444444444",
    "03_run_end_to_end": "55555555-5555-4555-8555-555555555555",
}


def metadata(display_name: str, item_type: str, description: str) -> dict[str, object]:
    return {
        "type": item_type,
        "displayName": display_name,
        "description": description,
    }


def config(display_name: str) -> dict[str, object]:
    return {
        "version": "1.0",
        "logicalId": LOGICAL_IDS.get(display_name, str(uuid.uuid4())),
    }


def write_json(path: Path, value: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def cell_source(cell: dict[str, object]) -> str:
    source = cell.get("source", [])
    if isinstance(source, list):
        return "\n".join(str(line).rstrip("\n") for line in source).rstrip()
    return str(source).rstrip()


def convert_notebook(ipynb_path: Path) -> str:
    notebook = json.loads(ipynb_path.read_text(encoding="utf-8"))
    parts: list[str] = [
        "# Fabric notebook source",
        "# METADATA ********************",
        "# META {",
        '# META   "kernel_info": {',
        '# META     "name": "synapse_pyspark"',
        "# META   },",
        '# META   "dependencies": {}',
        "# META }",
    ]

    for cell in notebook.get("cells", []):
        parts.append("# CELL ********************")
        source = cell_source(cell)
        if cell.get("cell_type") == "markdown":
            parts.extend(f"# MAGIC {line}" if line else "# MAGIC" for line in source.splitlines())
        else:
            parts.append(source)
        parts.extend(
            [
                "# METADATA ********************",
                "# META {",
                '# META   "language": "python",',
                '# META   "language_group": "synapse_pyspark"',
                "# META }",
            ]
        )

    return "\n".join(parts).rstrip() + "\n"


def main() -> None:
    lakehouse_dir = ITEM_ROOT / "lh_customer360.Lakehouse"
    write_json(lakehouse_dir / "item.metadata.json", metadata("lh_customer360", "Lakehouse", "Customer 360 demo Lakehouse for Bronze, Silver, and Gold tables."))
    write_json(lakehouse_dir / "item.config.json", config("lh_customer360"))

    for name, description in NOTEBOOKS:
        item_dir = ITEM_ROOT / f"{name}.Notebook"
        item_dir.mkdir(parents=True, exist_ok=True)
        write_json(item_dir / "item.metadata.json", metadata(name, "Notebook", description))
        write_json(item_dir / "item.config.json", config(name))
        content = convert_notebook(NOTEBOOK_SOURCE / f"{name}.ipynb")
        (item_dir / "notebook-content.py").write_text(content, encoding="utf-8")


if __name__ == "__main__":
    main()
