#!/usr/bin/env python3
"""
Build the PRISMA 2020 flow diagram for trading-systems-litreview.

Reads the corpus counts from results/logs/run_info.csv (if present) and
falls back to the reference-run snapshot otherwise. Writes:

    results/figures/prisma_flow.png
    results/figures/prisma_flow.svg

Run from the project root:

    python3 src/build_prisma_flow.py

Requires: matplotlib (pip install matplotlib).
"""

from __future__ import annotations

import csv
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch


# --------------------------------------------------------------------------
# Counts: read from run_info.csv if present, else fall back to reference run.
# --------------------------------------------------------------------------

REFERENCE_COUNTS = {
    "raw_rows": 588,
    "data_a_rows": 511,
    "data_b_rows": 511,
    "manual_review_rows": 20,
}


def load_counts() -> dict[str, int]:
    project_root = Path(__file__).resolve().parents[1]
    run_info = project_root / "results" / "logs" / "run_info.csv"
    counts = dict(REFERENCE_COUNTS)
    if run_info.is_file():
        with run_info.open() as f:
            for row in csv.DictReader(f):
                key = (row.get("item") or "").strip()
                val = (row.get("value") or "").strip()
                if key in counts and val.isdigit():
                    counts[key] = int(val)
    counts["duplicates_removed"] = counts["raw_rows"] - counts["data_a_rows"]
    counts["no_abstract"] = counts["data_a_rows"] - counts["data_b_rows"]
    counts["likely_related"] = counts["data_b_rows"] - counts["manual_review_rows"]
    return counts


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

PHASE_COLOR   = "#1F3864"
BOX_COLOR     = "#E7EBF3"
EXCLUDE_COLOR = "#F5E6E6"
BORDER_COLOR  = "#1F3864"


def build(counts: dict[str, int], out_dir: Path) -> None:
    fig, ax = plt.subplots(figsize=(11, 12))
    ax.set_xlim(-0.5, 11)
    ax.set_ylim(0, 14)
    ax.axis("off")

    def phase_label(y_top: float, y_bottom: float, text: str) -> None:
        h = y_top - y_bottom
        cy = (y_top + y_bottom) / 2
        ax.add_patch(FancyBboxPatch((-0.2, y_bottom), 1.2, h,
                                    boxstyle="round,pad=0.02",
                                    fc=PHASE_COLOR, ec=PHASE_COLOR))
        ax.text(0.4, cy, text, ha="center", va="center",
                color="white", fontsize=11, fontweight="bold", rotation=90)

    def box(x: float, y: float, w: float, h: float, text: str,
            fc: str = BOX_COLOR) -> None:
        ax.add_patch(FancyBboxPatch((x - w / 2, y - h / 2), w, h,
                                    boxstyle="round,pad=0.05",
                                    fc=fc, ec=BORDER_COLOR, lw=1.2))
        ax.text(x, y, text, ha="center", va="center", fontsize=10)

    def arrow(x1: float, y1: float, x2: float, y2: float) -> None:
        ax.add_patch(FancyArrowPatch((x1, y1), (x2, y2),
                                     arrowstyle="->", mutation_scale=20,
                                     color=BORDER_COLOR, lw=1.2))

    # Title
    ax.text(5.5, 13.5, "PRISMA 2020 flow diagram", ha="center", va="center",
            fontsize=15, fontweight="bold", color=PHASE_COLOR)
    ax.text(5.5, 13.05, "trading-systems-litreview — Scopus search, 2025-04",
            ha="center", va="center", fontsize=10, style="italic", color="#444")

    # Identification
    phase_label(12.5, 11.4, "Identification")
    box(5.5, 12.0, 5.0, 0.9,
        "Records identified from Scopus\n"
        "(20 search queries, English, 2015–2026)\n"
        f"n = {counts['raw_rows']}")
    arrow(5.5, 11.45, 5.5, 10.7)

    # Screening
    phase_label(10.7, 7.95, "Screening")
    box(5.5, 10.2, 5.0, 0.9,
        "Records after de-duplication on\nnormalised title key\n"
        f"n = {counts['data_a_rows']}")
    box(9.2, 10.2, 3.2, 0.9,
        "Duplicates removed\n(automated)\n"
        f"n = {counts['duplicates_removed']}",
        fc=EXCLUDE_COLOR)
    arrow(8.0, 10.2, 7.65, 10.2)

    arrow(5.5, 9.65, 5.5, 9.0)
    box(5.5, 8.5, 5.0, 0.9,
        "Records with non-empty abstract\n(eligible for text mining)\n"
        f"n = {counts['data_b_rows']}")
    box(9.2, 8.5, 3.2, 0.9,
        "Records without abstract\nremoved\n"
        f"n = {counts['no_abstract']}",
        fc=EXCLUDE_COLOR)
    arrow(8.0, 8.5, 7.65, 8.5)
    arrow(5.5, 7.95, 5.5, 7.3)

    # Eligibility
    phase_label(7.30, 4.30, "Eligibility")
    box(5.5, 6.8, 5.0, 0.9,
        "Records assessed for topic relevance\n"
        "(keyword-based topic_flag)\n"
        f"n = {counts['data_b_rows']}")
    arrow(5.5, 6.25, 3.5, 5.45)
    arrow(5.5, 6.25, 7.5, 5.45)
    box(3.5, 4.9, 3.4, 0.9,
        "Likely related\n(automatic include)\n"
        f"n = {counts['likely_related']}")
    box(7.5, 4.9, 3.4, 0.9,
        "Manual review queue\n(borderline cases)\n"
        f"n = {counts['manual_review_rows']}")
    arrow(3.5, 4.35, 3.5, 3.6)
    arrow(7.5, 4.35, 7.5, 3.6)

    # Included
    phase_label(4.30, 0.65, "Included")
    box(5.5, 3.0, 5.0, 0.9,
        "Studies included in synthesis\n"
        f"n = {counts['data_b_rows']}\n"
        f"({counts['likely_related']} likely related"
        f" + {counts['manual_review_rows']} manual review)")
    arrow(5.5, 2.45, 5.5, 1.7)
    box(5.5, 1.2, 7.0, 0.9,
        "Downstream analyses: top-20 terms · word cloud · correlation heatmap ·\n"
        "document map · term map · bibliometrix · VOSviewer maps")

    out_dir.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(out_dir / "prisma_flow.png", dpi=200,
                bbox_inches="tight", facecolor="white")
    fig.savefig(out_dir / "prisma_flow.svg",
                bbox_inches="tight", facecolor="white")
    plt.close(fig)


def main() -> None:
    project_root = Path(__file__).resolve().parents[1]
    out_dir = project_root / "results" / "figures"
    counts = load_counts()
    build(counts, out_dir)
    print(f"Wrote {out_dir / 'prisma_flow.png'}")
    print(f"Wrote {out_dir / 'prisma_flow.svg'}")


if __name__ == "__main__":
    main()
