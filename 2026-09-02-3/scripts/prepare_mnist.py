#!/usr/bin/env python3
"""Prepare deterministic MNIST subsets and a matching 784-16-10 MLP."""

from __future__ import annotations

import hashlib
import json
import tempfile
import urllib.request
from pathlib import Path

import numpy as np


SOURCE_URL = "https://storage.googleapis.com/tensorflow/tf-keras-datasets/mnist.npz"
SEED = 20260902
OUTPUT_DIR = Path(__file__).resolve().parents[1] / "public" / "data"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def stratified_indices(labels: np.ndarray, per_class: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    selected: list[np.ndarray] = []
    for digit in range(10):
        candidates = np.flatnonzero(labels == digit)
        selected.append(rng.choice(candidates, size=per_class, replace=False))
    result = np.concatenate(selected)
    rng.shuffle(result)
    return result


def one_hot(labels: np.ndarray) -> np.ndarray:
    values = np.zeros((len(labels), 10), dtype=np.float32)
    values[np.arange(len(labels)), labels] = 1.0
    return values


def softmax(logits: np.ndarray) -> np.ndarray:
    shifted = logits - logits.max(axis=1, keepdims=True)
    exp = np.exp(shifted)
    return exp / exp.sum(axis=1, keepdims=True)


def accuracy(x: np.ndarray, y: np.ndarray, params: dict[str, np.ndarray]) -> float:
    hidden = np.maximum(0.0, x @ params["w1"] + params["b1"])
    predictions = np.argmax(hidden @ params["w2"] + params["b2"], axis=1)
    return float(np.mean(predictions == y))


def train_model(x: np.ndarray, y: np.ndarray) -> tuple[dict[str, np.ndarray], list[float]]:
    rng = np.random.default_rng(SEED)
    limit1 = np.sqrt(6.0 / (784 + 16))
    limit2 = np.sqrt(6.0 / (16 + 10))
    params = {
        "w1": rng.uniform(-limit1, limit1, (784, 16)).astype(np.float32),
        "b1": np.zeros(16, dtype=np.float32),
        "w2": rng.uniform(-limit2, limit2, (16, 10)).astype(np.float32),
        "b2": np.zeros(10, dtype=np.float32),
    }
    labels = one_hot(y)
    learning_rate = 0.05
    batch_size = 128
    losses: list[float] = []

    for epoch in range(12):
        order = rng.permutation(len(x))
        for start in range(0, len(x), batch_size):
            batch = order[start : start + batch_size]
            xb = x[batch]
            yb = labels[batch]
            z1 = xb @ params["w1"] + params["b1"]
            a1 = np.maximum(0.0, z1)
            probabilities = softmax(a1 @ params["w2"] + params["b2"])
            grad_logits = (probabilities - yb) / len(batch)
            grad_w2 = a1.T @ grad_logits
            grad_b2 = grad_logits.sum(axis=0)
            grad_a1 = grad_logits @ params["w2"].T
            grad_z1 = grad_a1 * (z1 > 0)
            grad_w1 = xb.T @ grad_z1
            grad_b1 = grad_z1.sum(axis=0)
            params["w1"] -= learning_rate * grad_w1
            params["b1"] -= learning_rate * grad_b1
            params["w2"] -= learning_rate * grad_w2
            params["b2"] -= learning_rate * grad_b2

        sample = order[:1000]
        hidden = np.maximum(0.0, x[sample] @ params["w1"] + params["b1"])
        probs = softmax(hidden @ params["w2"] + params["b2"])
        loss = -np.mean(np.log(np.clip(probs[np.arange(len(sample)), y[sample]], 1e-7, 1.0)))
        losses.append(float(loss))
        print(f"epoch {epoch + 1:02d}/12 loss={loss:.4f}")

    return params, losses


def write_split(name: str, images: np.ndarray, labels: np.ndarray) -> dict[str, object]:
    image_path = OUTPUT_DIR / f"{name}-images.bin"
    label_path = OUTPUT_DIR / f"{name}-labels.bin"
    images.astype(np.uint8).tofile(image_path)
    labels.astype(np.uint8).tofile(label_path)
    return {
        "count": int(len(labels)),
        "images": image_path.name,
        "labels": label_path.name,
        "imagesSha256": sha256(image_path),
        "labelsSha256": sha256(label_path),
    }


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="mnist-source-") as temp_dir:
        source_path = Path(temp_dir) / "mnist.npz"
        print(f"downloading {SOURCE_URL}")
        urllib.request.urlretrieve(SOURCE_URL, source_path)
        source_digest = sha256(source_path)
        with np.load(source_path) as dataset:
            x_train = dataset["x_train"]
            y_train = dataset["y_train"]
            x_test = dataset["x_test"]
            y_test = dataset["y_test"]

    train_idx = stratified_indices(y_train, 500, SEED)
    test_idx = stratified_indices(y_test, 100, SEED + 1)
    guided_idx = stratified_indices(y_train, 10, SEED + 2)

    normalized_train = x_train.reshape(-1, 784).astype(np.float32) / 255.0
    normalized_test = x_test.reshape(-1, 784).astype(np.float32) / 255.0
    params, losses = train_model(normalized_train, y_train)

    weights_path = OUTPUT_DIR / "pretrained-weights.bin"
    with weights_path.open("wb") as weights_file:
        for name in ("w1", "b1", "w2", "b2"):
            params[name].astype(np.float32).tofile(weights_file)

    splits = {
        "guided": write_split("guided", x_train[guided_idx].reshape(-1, 784), y_train[guided_idx]),
        "train": write_split("train", x_train[train_idx].reshape(-1, 784), y_train[train_idx]),
        "test": write_split("test", x_test[test_idx].reshape(-1, 784), y_test[test_idx]),
    }
    manifest = {
        "version": 1,
        "source": {
            "url": SOURCE_URL,
            "sha256": source_digest,
            "license": "CC BY-SA 3.0",
            "attribution": "MNIST by Yann LeCun and Corinna Cortes, derived from NIST data",
        },
        "selection": {"seed": SEED, "method": "stratified fixed-count sampling"},
        "splits": splits,
        "model": {
            "architecture": [784, 16, 10],
            "optimizer": "SGD",
            "learningRate": 0.05,
            "epochs": 12,
            "trainingCount": 60000,
            "testCount": 10000,
            "testAccuracy": accuracy(normalized_test, y_test, params),
            "weights": weights_path.name,
            "weightsSha256": sha256(weights_path),
            "parameterOrder": ["w1", "b1", "w2", "b2"],
            "parameterShapes": [[784, 16], [16], [16, 10], [10]],
            "epochLoss": losses,
        },
    }
    manifest_path = OUTPUT_DIR / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"test accuracy={manifest['model']['testAccuracy']:.4f}")
    print(f"wrote {manifest_path}")


if __name__ == "__main__":
    main()
