"""measurements/*.json → assets/*.png (the step's visual example: what the containers cost and how they roll out).

footprint.png  what is inside the API image, and PyTorch vs onnxruntime
rollout.png    CI timeline on a GitHub-hosted runner + failed requests during a rolling restart, before/after preStop
"""

import json
from pathlib import Path

import matplotlib.pyplot as plt

M = Path("measurements")
LOCAL = json.loads((M / "local_docker.json").read_text())
RUN5 = json.loads((M / "ci_run5.json").read_text())
RUN6 = json.loads((M / "ci_run6.json").read_text())
Path("assets").mkdir(exist_ok=True)
BLUE, RED, GREEN, GRAY, ORANGE, DARK = "#2563eb", "#dc2626", "#16a34a", "#94a3b8", "#ea580c", "#1e293b"


def save(fig, name: str) -> None:
    fig.tight_layout()
    fig.savefig(f"assets/{name}", dpi=150)
    plt.close(fig)


def footprint() -> None:
    img = LOCAL["images"]
    base = img["python_3_12_slim_base_bytes"] / 1e6
    venv, models = img["api_layers_mb"]["venv"], img["api_layers_mb"]["models_baked_in"]
    torch_gb = LOCAL["pytorch_footprint"]["torch_nvidia_triton_in_step15_venv_gb"]
    ort = LOCAL["pytorch_footprint"]["onnxruntime_package_mb"]
    fig, (a, b) = plt.subplots(1, 2, figsize=(10, 3.4), gridspec_kw={"width_ratios": [1.3, 1]})
    left = 0
    for name, mb, color in (("python:3.12-slim", base, GRAY), ("Python packages", venv, BLUE), ("models", models, GREEN)):
        a.barh(0, mb, left=left, color=color, label=f"{name} ({mb:.0f} MB)")
        left += mb
    a.barh(1, img["web_bytes"] / 1e6, color=ORANGE, label=f"web image ({img['web_bytes'] / 1e6:.0f} MB)")
    a.set(yticks=[0, 1], yticklabels=["api (onnx)", "web (nginx)"], xlabel="MB, uncompressed")
    a.invert_yaxis()
    a.legend(fontsize=7, loc="lower right")
    a.set_title("What is inside the images", fontsize=10)
    bars = b.bar(["PyTorch + CUDA libs", "onnxruntime"], [torch_gb * 1000, ort], color=[RED, BLUE])
    b.bar_label(bars, labels=[f"{torch_gb} GB", f"{ort} MB"], fontsize=8)
    b.set(ylabel="MB on disk")
    b.set_title("Inference runtime alone", fontsize=10)
    save(fig, "footprint.png")


def rollout() -> None:
    fig, (a, b) = plt.subplots(1, 2, figsize=(10, 3.2), gridspec_kw={"width_ratios": [1.6, 1]})
    k, c = RUN6["kind"], RUN5["compose"]
    rows = [
        ("docker compose", [("build (cached)", c["build_s_with_layer_cache"], GRAY),
                            ("stack up (incl. indexing)", c["up_to_all_healthy_s"], BLUE)]),
        ("kind (Kubernetes)", [("deploy (incl. indexing)", k["deploy_s"], BLUE),
                               ("rolling restart", k["rollout_restart_s"], GREEN)]),
    ]  # fmt: skip
    for y, (_label, parts) in enumerate(rows):
        left = 0
        for name, s, color in parts:
            a.barh(y, s, left=left, color=color)
            a.text(left + s / 2, y, f"{name}\n{s:.0f} s" if s > 60 else "", ha="center", va="center", fontsize=7,
                   color="white")  # fmt: skip
            left += s
    a.set(yticks=[0, 1], yticklabels=[r[0] for r in rows], xlabel="seconds on a GitHub-hosted runner")
    a.invert_yaxis()
    a.set_title("CI: most of the time is embedding 5218 chunks", fontsize=10)
    p5, p6 = RUN5["kind"]["probe"], RUN6["kind"]["probe"]
    bars = b.bar(["no preStop\n(run 5)", "preStop sleep 10\n(run 6)"], [p5["failed"], p6["failed"]], color=[RED, GREEN])
    b.bar_label(bars, labels=[f"{p5['failed']} / {p5['requests']}", f"{p6['failed']} / {p6['requests']}"], fontsize=8)
    b.set(ylabel="failed requests", ylim=(0, max(p5["failed"], 1) * 1.4))
    b.set_title("During a rolling restart of the API", fontsize=10)
    save(fig, "rollout.png")


if __name__ == "__main__":
    footprint()
    rollout()
