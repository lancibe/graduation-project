# -*- coding: utf-8 -*-
"""
Created on Wed Apr 19 17:47:57 2023

@author: 16095
"""

import torch
import os
import numpy as np
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
from torchaudio.datasets import LIBRISPEECH
from torchaudio.transforms import MFCC
import torchaudio

class CustomDataset(Dataset):
    def __init__(self, trans_file, wav_file):
        self.trans_data = {}
        self.trans_data = dict()
        self.wav_data = dict()
        with open(trans_file, 'r', encoding='utf-8') as f:
            for line in f:
                parts = line.strip().split('\t')
                if len(parts) == 2:
                    audio_id, label = parts
                    self.trans_data[audio_id] = label
        
        self.wav_data = {}
        with open(wav_file, 'r', encoding='utf-8') as f:
            for line in f:
                parts = line.strip().split('\t')
                if len(parts) == 2:
                    audio_id, path = parts
                    self.wav_data[audio_id] = path
        
        self.audio_ids = list(self.trans_data.keys())

    def __getitem__(self, idx):
        audio_id = self.audio_ids[idx]
        audio_path = self.wav_data[audio_id]
        waveform, sample_rate = torchaudio.load(audio_path)
        label = self.trans_data[audio_id]
        return waveform, label

    def __len__(self):
        return len(self.audio_ids)

train_dataset = CustomDataset('trans.txt', 'wav.scp')
test_dataset = CustomDataset('trans.txt', 'wav.scp')

class MFCCPreprocess(nn.Module):
    def __init__(self, sample_rate=16000, n_mfcc=13):
        super().__init__()
        self.mfcc_transform = MFCC(sample_rate=sample_rate, n_mfcc=n_mfcc)
    
    def forward(self, waveform):
        mfcc = self.mfcc_transform(waveform)
        return mfcc



def collate_fn(batch):
    waveforms, labels = zip(*batch)
    waveforms_lengths = [len(w) for w in waveforms]
    max_length = max(waveforms_lengths)
    
    padded_waveforms = np.zeros((len(waveforms), max_length), dtype=np.float32)
    for i, w in enumerate(waveforms):
        if len(w) > max_length:
            w = w[:max_length]
        padded_waveforms[i, :len(w)] = w
    return {"input": torch.from_numpy(padded_waveforms), "target": torch.tensor(labels)}

train_dataloader = DataLoader(train_dataset, batch_size=4, shuffle=True, collate_fn=collate_fn)
test_dataloader = DataLoader(test_dataset, batch_size=4, shuffle=False, collate_fn=collate_fn)


mfcc_transform = MFCC(sample_rate=16000, n_mfcc=13)

def preprocess(data):
    waveform, sample_rate, utterance = data
    mfcc = mfcc_transform(waveform)
    return {"input": mfcc, "target": torch.tensor(utterance)}


class TransformerASR(nn.Module):
    def __init__(self, input_dim, vocab_size, d_model=512, nhead=8, num_layers=6):
        super().__init__()
        self.encoder_layer = nn.TransformerEncoderLayer(d_model=d_model, nhead=nhead)
        self.encoder = nn.TransformerEncoder(self.encoder_layer, num_layers=num_layers)
        self.fc = nn.Linear(d_model * input_dim, vocab_size)
        
    def forward(self, x):
        # x shape: (seq_len, batch_size, input_dim)
        x = self.encoder(x)
        x = x.permute(1, 0, 2).contiguous().view(x.size(1), -1) # flatten
        x = self.fc(x)
        return x


model = TransformerASR(input_dim=13, vocab_size=train_dataset.__len__())
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=0.001)

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model.to(device)

for epoch in range(10):
    running_loss = 0.0
    for data in train_dataloader:
        inputs, targets = data["input"].to(device), data["target"].to(device)
        optimizer.zero_grad()
        outputs = model(inputs)
        loss = criterion(outputs, targets)
        loss.backward()
        optimizer.step()
        running_loss += loss.item()
    print(f"epoch {epoch+1}, loss: {running_loss/len(train_dataloader)}")

# 测试模型
model.eval()
correct = 0
total = 0
with torch.no_grad():
    for data in test_dataloader:
        inputs, targets = data["input"].to(device), data["target"].to(device)
        outputs = model(inputs)
        _, predicted = torch.max(outputs.data, 1)
        total += targets.size(0)
        correct += (predicted == targets).sum().item()

print(f"Accuracy on test set: {100 * correct / total}%")

