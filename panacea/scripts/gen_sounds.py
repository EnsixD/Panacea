#!/usr/bin/env python3
import os
import math
import struct
import wave

SAMPLE_RATE = 48000

def create_wav(filename, samples):
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(SAMPLE_RATE)
        packed_samples = bytearray()
        for s in samples:
            val = max(-1.0, min(1.0, s))
            int_val = int(val * 32767.0)
            packed_samples += struct.pack('<h', int_val)
        wav_file.writeframes(packed_samples)

def gen_charge():
    # Ascending warm double-pulse (Nothing OS / Apple style)
    duration = 0.22
    total_samples = int(SAMPLE_RATE * duration)
    samples = [0.0] * total_samples
    
    # Pulse 1: D5 (587.33 Hz)
    p1_len = int(SAMPLE_RATE * 0.08)
    for i in range(p1_len):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * i / p1_len) ** 1.5 * math.exp(-t * 25)
        # Sine + gentle 2nd harmonic
        sig = math.sin(2 * math.pi * 587.33 * t) * 0.7 + math.sin(2 * math.pi * 1174.66 * t) * 0.15
        samples[i] += sig * env * 0.55
        
    # Pulse 2: A5 (880.0 Hz) at t = 0.055s
    p2_start = int(SAMPLE_RATE * 0.055)
    p2_len = int(SAMPLE_RATE * 0.15)
    for i in range(p2_len):
        idx = p2_start + i
        if idx >= total_samples: break
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * i / p2_len) ** 1.2 * math.exp(-t * 16)
        sig = math.sin(2 * math.pi * 880.0 * t) * 0.75 + math.sin(2 * math.pi * 1760.0 * t) * 0.18 + math.sin(2 * math.pi * 2640.0 * t) * 0.05
        samples[idx] += sig * env * 0.65
        
    return samples

def gen_connect():
    # Warm harmonic rising chime
    duration = 0.20
    total_samples = int(SAMPLE_RATE * duration)
    samples = [0.0] * total_samples
    
    # E5 (659.25 Hz) -> B5 (987.77 Hz)
    p1_len = int(SAMPLE_RATE * 0.09)
    for i in range(p1_len):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * i / p1_len) * math.exp(-t * 20)
        sig = math.sin(2 * math.pi * 659.25 * t) * 0.7 + math.sin(2 * math.pi * 1318.5 * t) * 0.12
        samples[i] += sig * env * 0.5
        
    p2_start = int(SAMPLE_RATE * 0.05)
    p2_len = int(SAMPLE_RATE * 0.14)
    for i in range(p2_len):
        idx = p2_start + i
        if idx >= total_samples: break
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * i / p2_len) * math.exp(-t * 15)
        sig = math.sin(2 * math.pi * 987.77 * t) * 0.75 + math.sin(2 * math.pi * 1975.5 * t) * 0.15
        samples[idx] += sig * env * 0.6
        
    return samples

def gen_disconnect():
    # Subtle downward soft tone (G5 -> C5)
    duration = 0.16
    total_samples = int(SAMPLE_RATE * duration)
    samples = [0.0] * total_samples
    
    p1_len = int(SAMPLE_RATE * 0.07)
    for i in range(p1_len):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * i / p1_len) * math.exp(-t * 22)
        sig = math.sin(2 * math.pi * 783.99 * t) * 0.65
        samples[i] += sig * env * 0.45
        
    p2_start = int(SAMPLE_RATE * 0.045)
    p2_len = int(SAMPLE_RATE * 0.11)
    for i in range(p2_len):
        idx = p2_start + i
        if idx >= total_samples: break
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * i / p2_len) * math.exp(-t * 18)
        sig = math.sin(2 * math.pi * 523.25 * t) * 0.65
        samples[idx] += sig * env * 0.45
        
    return samples

def gen_screenshot():
    # Tactile shutter / snap
    duration = 0.09
    total_samples = int(SAMPLE_RATE * duration)
    samples = [0.0] * total_samples
    
    # Sharp tactile transient click
    click_len = int(SAMPLE_RATE * 0.015)
    for i in range(click_len):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 300)
        noise = (math.sin(2 * math.pi * 3200 * t) + math.sin(2 * math.pi * 1800 * t)) * 0.5
        samples[i] += noise * env * 0.6
        
    # Metallic body resonance (1100 Hz)
    body_len = int(SAMPLE_RATE * 0.08)
    for i in range(body_len):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 45) * math.sin(math.pi * i / body_len) ** 0.5
        sig = math.sin(2 * math.pi * 1100 * t) * 0.6 + math.sin(2 * math.pi * 2200 * t) * 0.2
        samples[i] += sig * env * 0.5
        
    return samples

def gen_voice_start():
    # Modern radar blip (rising chirp)
    duration = 0.08
    total_samples = int(SAMPLE_RATE * duration)
    samples = [0.0] * total_samples
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        freq = 520 + (t / duration) * 440  # 520 -> 960 Hz
        env = math.sin(math.pi * (i / total_samples)) * math.exp(-t * 20)
        sig = math.sin(2 * math.pi * freq * t) * 0.65 + math.sin(4 * math.pi * freq * t) * 0.15
        samples[i] = sig * env * 0.55
    return samples

def gen_voice_done():
    # Soft completion blip (falling chirp)
    duration = 0.10
    total_samples = int(SAMPLE_RATE * duration)
    samples = [0.0] * total_samples
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        freq = 960 - (t / duration) * 360  # 960 -> 600 Hz
        env = math.sin(math.pi * (i / total_samples)) * math.exp(-t * 18)
        sig = math.sin(2 * math.pi * freq * t) * 0.65 + math.sin(2 * math.pi * (freq * 1.5) * t) * 0.15
        samples[i] = sig * env * 0.5
    return samples

def main():
    base_dir = "/home/ensi/Panacea/panacea/sounds"
    sounds = {
        "charge.wav": gen_charge(),
        "connect.wav": gen_connect(),
        "disconnect.wav": gen_disconnect(),
        "screenshot.wav": gen_screenshot(),
        "voice_start.wav": gen_voice_start(),
        "voice_done.wav": gen_voice_done(),
    }
    for name, s in sounds.items():
        path = os.path.join(base_dir, name)
        create_wav(path, s)
        print(f"Generated {path}")

if __name__ == "__main__":
    main()
