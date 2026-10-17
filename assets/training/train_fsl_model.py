#!/usr/bin/env python3
"""
Train an FSL sign classifier from collected landmark data.

Supports both:
  --mode static:   MLP on single frames (63 → 128 → 64 → N)
  --mode temporal: Conv1D on 30-frame windows (30×63 → 64ch Conv → 128ch Conv → N)

Usage:
  python train_fsl_model.py --mode temporal --data path/to/sequences.csv --output path/to/fsl_temporal_weights.json

For temporal CSV format:
  sign_id,label,frame_idx,x0,y0,z0,...,x20,y20,z20
  Each sequence = 30 consecutive rows with frame_idx 0..29
"""

import json
import argparse
import csv
import os
import sys
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset
import random
from collections import defaultdict


# ---------------------------------------------------------------------------
# Static MLP classifier (existing)
# ---------------------------------------------------------------------------

class FSLClassifier(nn.Module):
    def __init__(self, num_classes: int):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(63, 128),
            nn.ReLU(),
            nn.Dropout(0.2),
            nn.Linear(128, 64),
            nn.ReLU(),
            nn.Dropout(0.2),
            nn.Linear(64, num_classes),
        )

    def forward(self, x):
        return self.net(x)

    def predict(self, x):
        with torch.no_grad():
            logits = self.forward(x)
            probs = torch.softmax(logits, dim=1)
            return probs

    def export_weights(self) -> dict:
        state = self.state_dict()
        weights = {}
        for key, tensor in state.items():
            weights[key] = tensor.cpu().numpy().tolist()
        return weights

    @classmethod
    def from_weights(cls, weights: dict, num_classes: int) -> "FSLClassifier":
        model = cls(num_classes)
        state = {}
        for key, val in weights.items():
            state[key] = torch.tensor(val)
        model.load_state_dict(state)
        model.eval()
        return model


# ---------------------------------------------------------------------------
# Temporal Conv1D classifier (NEW)
# ---------------------------------------------------------------------------

class TemporalFSLClassifier(nn.Module):
    """
    Input: [B, 30, 63]  (batch, time, landmark_coords)
    Architecture:
      Conv1D(64, k=5, padding=2) + ReLU   → [B, 30, 64]
      Conv1D(128, k=3, padding=1) + ReLU  → [B, 30, 128]
      GlobalAvgPool(time)                  → [B, 128]
      Dense(64) + ReLU                     → [B, 64]
      Dense(N)                             → [B, N]
    """
    def __init__(self, num_classes: int):
        super().__init__()
        self.conv1 = nn.Conv1d(63, 64, kernel_size=5, padding=2)
        self.conv2 = nn.Conv1d(64, 128, kernel_size=3, padding=1)
        self.fc1 = nn.Linear(128, 64)
        self.fc2 = nn.Linear(64, num_classes)
        self.dropout = nn.Dropout(0.2)

    def forward(self, x):
        # x: [B, 30, 63] → permute to [B, 63, 30] for Conv1d
        x = x.permute(0, 2, 1)
        x = torch.relu(self.conv1(x))       # [B, 64, 30]
        x = self.dropout(x)
        x = torch.relu(self.conv2(x))       # [B, 128, 30]
        x = self.dropout(x)
        x = x.mean(dim=2)                   # [B, 128]  GlobalAvgPool
        x = torch.relu(self.fc1(x))         # [B, 64]
        x = self.fc2(x)                     # [B, N]
        return x

    def predict(self, x):
        with torch.no_grad():
            logits = self.forward(x)
            probs = torch.softmax(logits, dim=1)
            return probs

    def export_weights(self) -> dict:
        state = self.state_dict()
        weights = {}
        for key, tensor in state.items():
            weights[key] = tensor.cpu().numpy().tolist()
        return weights

    @classmethod
    def from_weights(cls, weights: dict, num_classes: int) -> "TemporalFSLClassifier":
        model = cls(num_classes)
        state = {}
        for key, val in weights.items():
            state[key] = torch.tensor(val)
        model.load_state_dict(state)
        model.eval()
        return model


# ---------------------------------------------------------------------------
# Preprocessing (static)
# ---------------------------------------------------------------------------

def preprocess_landmarks(landmarks: np.ndarray) -> np.ndarray:
    """
    Preprocess landmarks identically to Dart inference:
    1. Wrist-center: subtract landmark 0 from all landmarks
    2. Normalize by middle finger length (distance from MCP[9] to TIP[12])
    """
    pts = landmarks.reshape(21, 3)
    wrist = pts[0]
    centered = pts - wrist
    mcp = pts[9]
    tip = pts[12]
    mid_len = np.linalg.norm(tip - mcp)
    if mid_len > 0.001:
        normalized = centered / mid_len
    else:
        normalized = centered
    return normalized.flatten().astype(np.float32)


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

def load_static_csv(path: str) -> tuple:
    """Load single-frame CSV: sign_id, label, x0,y0,z0,..."""
    X, y, label_names = [], [], []
    id_to_label = {}
    label_to_idx = {}
    with open(path, "r") as f:
        reader = csv.reader(f)
        header = next(reader)
        for row in reader:
            if not row:
                continue
            sign_id = int(row[0])
            label = row[1]
            landmarks = [float(v) for v in row[2:]]
            if len(landmarks) == 63:
                processed = preprocess_landmarks(np.array(landmarks, dtype=np.float32))
                X.append(processed)
                id_to_label[sign_id] = label
                y.append(sign_id)

    unique_ids = sorted(set(y))
    for i, sid in enumerate(unique_ids):
        label_to_idx[sid] = i
    label_names = [id_to_label[sid] for sid in unique_ids]
    y = [label_to_idx[sid] for sid in y]

    return np.array(X, dtype=np.float32), np.array(y, dtype=np.int64), label_names


def load_temporal_csv(path: str) -> tuple:
    """
    Load temporal CSV: sign_id, label, frame_idx, x0,y0,...
    Groups consecutive frame_idx 0..29 into sequences of shape [30, 63].
    """
    sequences = []
    labels = []
    label_names = []
    id_to_label = {}
    label_to_idx = {}

    # Group by (sign_id, label) and sort by frame_idx
    rows_by_sign = defaultdict(list)
    with open(path, "r") as f:
        reader = csv.reader(f)
        header = next(reader)
        for row in reader:
            if not row:
                continue
            sign_id = int(row[0])
            label = row[1]
            frame_idx = int(row[2])
            landmarks = [float(v) for v in row[3:]]
            rows_by_sign[(sign_id, label)].append((frame_idx, landmarks))

    sample_count = 0
    for (sign_id, label), frames in rows_by_sign.items():
        frames.sort(key=lambda x: x[0])
        coords = np.array([f[1] for f in frames], dtype=np.float32)
        # Split into chunks of 30
        for start in range(0, len(coords) - 29, 15):  # 15-frame stride for overlap
            chunk = coords[start:start + 30]
            if chunk.shape != (30, 63):
                continue
            # Preprocess each frame
            processed = np.array([preprocess_landmarks(f) for f in chunk], dtype=np.float32)
            sequences.append(processed)
            id_to_label[sign_id] = label
            labels.append(sign_id)
            sample_count += 1

    unique_ids = sorted(set(labels))
    for i, sid in enumerate(unique_ids):
        label_to_idx[sid] = i
    label_names = [id_to_label[sid] for sid in unique_ids]
    labels = [label_to_idx[sid] for sid in labels]

    if len(sequences) == 0:
        raise ValueError("No valid temporal sequences found in CSV")

    return np.array(sequences, dtype=np.float32), np.array(labels, dtype=np.int64), label_names


# ---------------------------------------------------------------------------
# Augmentation
# ---------------------------------------------------------------------------

def augment_static(landmarks: np.ndarray, rotation_range=15.0, scale_range=0.2, noise_std=0.03) -> np.ndarray:
    """Augment a single frame of 63 landmarks."""
    pts = landmarks.reshape(21, 3)
    angle = np.radians(random.uniform(-rotation_range, rotation_range))
    cos_a, sin_a = np.cos(angle), np.sin(angle)
    rot = np.array([[cos_a, -sin_a, 0], [sin_a, cos_a, 0], [0, 0, 1]])
    rotated = pts @ rot.T
    scale = 1.0 + random.uniform(-scale_range, scale_range)
    scaled = rotated * scale
    noise = np.random.normal(0, noise_std, scaled.shape)
    return (scaled + noise).flatten().astype(np.float32)


def augment_temporal(sequence: np.ndarray) -> np.ndarray:
    """
    Augment a temporal sequence [30, 63]:
    - Random rotation, scaling, noise per frame (same params for all frames)
    - Random temporal scaling (speed up/slow down by dropping/duplicating frames)
    - Random frame dropout (zero out a few frames)
    """
    seq = sequence.copy()
    t, c = seq.shape

    # Apply same rotation/scale/noise to all frames
    angle = np.radians(random.uniform(-15.0, 15.0))
    cos_a, sin_a = np.cos(angle), np.sin(angle)
    rot = np.array([[cos_a, -sin_a, 0], [sin_a, cos_a, 0], [0, 0, 1]])
    scale = 1.0 + random.uniform(-0.2, 0.2)

    for i in range(t):
        pts = seq[i].reshape(21, 3)
        rotated = pts @ rot.T
        scaled = rotated * scale
        noise = np.random.normal(0, 0.03, scaled.shape)
        seq[i] = (scaled + noise).flatten()

    # Temporal scaling: randomly drop or duplicate up to 3 frames
    if random.random() < 0.3:
        if random.random() < 0.5 and t > 20:
            # Drop 1-3 frames
            drop = random.randint(1, min(3, t - 20))
            idx = random.randint(0, t - drop)
            seq = np.delete(seq, slice(idx, idx + drop), axis=0)
        elif t < 30:
            # Duplicate random frames
            dup = random.randint(1, min(3, 30 - t))
            idx = random.randint(0, t - 1)
            extra = np.repeat(seq[idx:idx+1], dup, axis=0)
            seq = np.concatenate([seq, extra], axis=0)
        # Trim/pad to exactly 30
        if len(seq) < 30:
            pad = np.repeat(seq[-1:], 30 - len(seq), axis=0)
            seq = np.concatenate([seq, pad], axis=0)
        elif len(seq) > 30:
            seq = seq[:30]

    # Frame dropout: zero out 1-2 random frames
    if random.random() < 0.2:
        n_drop = random.randint(1, 2)
        for _ in range(n_drop):
            idx = random.randint(0, 29)
            seq[idx] = 0.0

    return seq.astype(np.float32)


# ---------------------------------------------------------------------------
# Training
# ---------------------------------------------------------------------------

def train_static(X, y, num_classes, epochs=200, batch_size=32, lr=0.001):
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Using device: {device}")

    X_tensor = torch.from_numpy(X).to(device)
    y_tensor = torch.from_numpy(y).to(device)
    dataset = TensorDataset(X_tensor, y_tensor)
    loader = DataLoader(dataset, batch_size=batch_size, shuffle=True)

    model = FSLClassifier(num_classes).to(device)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=lr)
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, patience=10, factor=0.5)

    best_loss = float("inf")
    patience_counter = 0

    for epoch in range(epochs):
        model.train()
        total_loss = 0.0
        for batch_X, batch_y in loader:
            batch_X_np = batch_X.cpu().numpy()
            augmented = np.array([augment_static(x) for x in batch_X_np])
            batch_X_aug = torch.from_numpy(augmented).to(device)

            optimizer.zero_grad()
            outputs = model(batch_X_aug)
            loss = criterion(outputs, batch_y)
            loss.backward()
            optimizer.step()
            total_loss += loss.item()

        avg_loss = total_loss / len(loader)
        val_loss, val_acc = validate(model, X_tensor, y_tensor)
        scheduler.step(val_loss)

        if val_loss < best_loss:
            best_loss = val_loss
            patience_counter = 0
        else:
            patience_counter += 1

        if (epoch + 1) % 20 == 0:
            print(f"Epoch {epoch+1}/{epochs} - Loss: {avg_loss:.4f} - ValLoss: {val_loss:.4f} - Acc: {val_acc:.2%}")

        if patience_counter >= 30:
            print(f"Early stopping at epoch {epoch+1}")
            break

    model.eval()
    _, final_acc = validate(model, X_tensor, y_tensor)
    print(f"\nTraining complete. Final accuracy: {final_acc:.2%}")
    return model


def train_temporal(X, y, num_classes, epochs=200, batch_size=16, lr=0.001):
    """Train the temporal Conv1D classifier."""
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Using device: {device}")
    print(f"Data shape: {X.shape} (sequences × 30 frames × 63 coords)")

    X_tensor = torch.from_numpy(X).to(device)
    y_tensor = torch.from_numpy(y).to(device)
    dataset = TensorDataset(X_tensor, y_tensor)
    loader = DataLoader(dataset, batch_size=batch_size, shuffle=True)

    model = TemporalFSLClassifier(num_classes).to(device)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=lr)
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, patience=10, factor=0.5)

    best_loss = float("inf")
    patience_counter = 0

    for epoch in range(epochs):
        model.train()
        total_loss = 0.0
        for batch_X, batch_y in loader:
            batch_X_np = batch_X.cpu().numpy()
            augmented = np.array([augment_temporal(x) for x in batch_X_np])
            batch_X_aug = torch.from_numpy(augmented).to(device)

            optimizer.zero_grad()
            outputs = model(batch_X_aug)
            loss = criterion(outputs, batch_y)
            loss.backward()
            optimizer.step()
            total_loss += loss.item()

        avg_loss = total_loss / len(loader)
        val_loss, val_acc = validate(model, X_tensor, y_tensor)
        scheduler.step(val_loss)

        if val_loss < best_loss:
            best_loss = val_loss
            patience_counter = 0
        else:
            patience_counter += 1

        if (epoch + 1) % 20 == 0:
            print(f"Epoch {epoch+1}/{epochs} - Loss: {avg_loss:.4f} - ValLoss: {val_loss:.4f} - Acc: {val_acc:.2%}")

        if patience_counter >= 30:
            print(f"Early stopping at epoch {epoch+1}")
            break

    model.eval()
    _, final_acc = validate(model, X_tensor, y_tensor)
    print(f"\nTraining complete. Final accuracy: {final_acc:.2%}")
    return model


def validate(model, X, y):
    """Compute loss and accuracy on a dataset."""
    model.eval()
    with torch.no_grad():
        outputs = model(X)
        loss = nn.CrossEntropyLoss()(outputs, y)
        _, predicted = torch.max(outputs, 1)
        acc = (predicted == y).sum().item() / y.size(0)
    model.train()
    return loss.item(), acc


def save_weights(model, output_path: str, label_names: list, mode: str):
    weights = model.export_weights()
    if mode == "static":
        architecture = "feedforward"
        input_dim = 63
        hidden_dims = [128, 64]
    else:
        architecture = "conv1d_temporal"
        input_dim = [30, 63]
        hidden_dims = ["Conv1D(64,k5)", "Conv1D(128,k3)", "FC(64)"]
    data = {
        "architecture": architecture,
        "input_dim": input_dim,
        "hidden_dims": hidden_dims,
        "num_classes": len(label_names),
        "label_names": label_names,
        "weights": weights,
    }
    with open(output_path, "w") as f:
        json.dump(data, f, indent=2)
    print(f"Model weights saved to {output_path}")
    print(f"  Classes: {len(label_names)}")
    print(f"  Mode: {mode}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Train FSL sign classifier")
    parser.add_argument("--mode", choices=["static", "temporal"], default="static",
                        help="Training mode: static (single frame) or temporal (30-frame sequences)")
    parser.add_argument("--data", required=True, help="Path to training CSV")
    parser.add_argument("--output", default=None,
                        help="Output path for weights JSON")
    parser.add_argument("--epochs", type=int, default=200, help="Training epochs")
    parser.add_argument("--batch-size", type=int, default=32, help="Batch size")
    parser.add_argument("--lr", type=float, default=0.001, help="Learning rate")
    args = parser.parse_args()

    # Set default output paths
    if args.output is None:
        if args.mode == "static":
            args.output = "assets/model/fsl_model_weights.json"
        else:
            args.output = "assets/model/fsl_temporal_weights.json"

    print(f"Loading data from {args.data}...")
    print(f"Mode: {args.mode}")

    if args.mode == "static":
        X, y, label_names = load_static_csv(args.data)
    else:
        X, y, label_names = load_temporal_csv(args.data)

    num_classes = len(np.unique(y))
    print(f"Loaded {len(X)} samples, {num_classes} classes")
    print(f"Labels: {label_names}")

    if args.mode == "static":
        model = train_static(X, y, num_classes, epochs=args.epochs,
                             batch_size=args.batch_size, lr=args.lr)
    else:
        model = train_temporal(X, y, num_classes, epochs=args.epochs,
                               batch_size=min(args.batch_size, 16), lr=args.lr)

    output_dir = os.path.dirname(args.output)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)
    save_weights(model, args.output, label_names, args.mode)

    print("\nDone! Copy the weights file to assets/model/ in your Flutter project.")


if __name__ == "__main__":
    main()
