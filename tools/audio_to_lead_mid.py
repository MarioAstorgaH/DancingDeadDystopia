"""Genera el lead.mid de una canción a partir de su audio, para cuando no hay MIDI.

1. Mide el tempo y dónde cae el primer tiempo en el fondo (`audio` de song.json).
   Supone tempo fijo, como en una canción grabada con metrónomo, y avisa si no lo es.
2. Transcribe la melodía (`lead` de song.json) con basic-pitch.
3. Deja una nota a la vez y la ajusta a la rejilla de semicorcheas o de tresillos,
   para que el juego le asigne su figura.

Necesita un entorno con basic-pitch (sin TensorFlow, usa el modelo ONNX), onnxruntime y librosa:
    python3 -m venv ~/transcribe-env
    ~/transcribe-env/bin/pip install --no-deps basic-pitch==0.4.0
    ~/transcribe-env/bin/pip install librosa mir-eval pretty-midi "resampy<0.4.3" scikit-learn scipy onnxruntime setuptools

Uso (después, correr tools/midi_to_chart.gd para generar el chart.json):
    ~/transcribe-env/bin/python tools/audio_to_lead_mid.py Assets/Songs/<id> [--min-gap 0.25]
"""

import argparse
import json
import logging
import math
import struct
from pathlib import Path

import librosa
import numpy as np

TPQ = 480  # ticks por negra en el MIDI
GRIDS = (4, 3)  # subdivisiones a las que se ajustan las notas: semicorcheas y tresillos
TRIPLET_BIAS = 0.5  # un tiempo es de tresillos si su error en tresillo es menor a esta fracción
SECTION = 20.0  # segundos por sección al revisar que el tempo sea fijo
MAX_DRIFT = 0.04  # segundos que puede desviarse una sección de la rejilla
LEGATO_GAP = 0.05  # segundos: fragmentos de la misma nota más juntos que esto se unen
QUIET_DB = -40.0  # dB respecto al pico de la melodía: más bajo es residuo de la separación


def measure_tempo(path: Path) -> tuple[float, float]:
    """Devuelve (segundos por tiempo, segundo del primer tiempo)."""
    y, sr = librosa.load(path, sr=22050)
    hop = 64
    env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop)
    env = env / env.max()
    fps = sr / hop
    duration = len(y) / sr

    def score(ibi: float, phase: float, start: float = 0.0, end: float = duration) -> float:
        times = np.arange(phase, end, ibi)
        idx = np.round(times[times >= start] * fps).astype(int)
        return env[idx[idx < len(env)]].mean()

    rough, _ = librosa.beat.beat_track(onset_envelope=env, sr=sr, hop_length=hop)
    rough = float(np.atleast_1d(rough)[0])
    best = (-1.0, 0.0, 0.0)
    for bpm in np.arange(rough - 1.5, rough + 1.5, 0.005):
        ibi = 60.0 / bpm
        for phase in np.arange(0.0, ibi, 0.004):
            s = score(ibi, phase)
            if s > best[0]:
                best = (s, ibi, phase)
    _, ibi, phase = best
    print(f"tempo {60 / ibi:.3f} BPM, primer tiempo en {phase:.3f} s")

    shifts = np.arange(-0.1, 0.1, 0.002)
    for start in np.arange(0.0, duration, SECTION):
        local = [score(ibi, phase + d, start, start + SECTION) for d in shifts]
        drift = shifts[int(np.argmax(local))]
        if abs(drift) > MAX_DRIFT:
            print(f"  AVISO: {start:.0f}-{start + SECTION:.0f} s se desvía {drift * 1000:+.0f} ms; el tempo no es fijo")
    return ibi, phase


class BeatGrid:
    """Tiempo 0 del MIDI = inicio del audio. Si el primer tiempo no cae en 0, el primer
    compás lleva un tempo propio para que los tiempos de la canción sean negras enteras."""

    def __init__(self, ibi: float, phase: float):
        self.ibi = ibi
        self.anchor = phase if phase >= ibi / 2 else phase + ibi  # primer tiempo después de 0
        self.anchor_beat = max(1, round(self.anchor / ibi))
        self.pickup = self.anchor / self.anchor_beat  # segundos por tiempo antes del ancla

    def beat_at(self, time: float) -> float:
        if time < self.anchor:
            return time / self.pickup
        return self.anchor_beat + (time - self.anchor) / self.ibi


def transcribe(path: Path) -> list[tuple[float, float, int, float]]:
    """Notas (inicio, fin, nota MIDI, intensidad) de la melodía, en segundos."""
    logging.disable(logging.WARNING)  # avisos de backends que no se usan
    from basic_pitch import ICASSP_2022_MODEL_PATH
    from basic_pitch.inference import predict

    _, _, events = predict(
        str(path), ICASSP_2022_MODEL_PATH,
        onset_threshold=0.5, frame_threshold=0.3, minimum_note_length=100,
        minimum_frequency=80, maximum_frequency=1100, melodia_trick=True)
    return sorted((float(s), float(e), int(p), float(a)) for s, e, p, a, *_ in events)


def drop_quiet(notes, path: Path):
    """Quita notas donde la melodía casi no suena: basic-pitch normaliza el audio y
    transcribe hasta el residuo de otros instrumentos que deja la separación."""
    y, sr = librosa.load(path, sr=22050)
    hop = 512
    rms = librosa.feature.rms(y=y, hop_length=hop)[0]
    level = 20 * np.log10(rms / rms.max() + 1e-9)
    kept = [n for n in notes
            if level[int(n[0] * sr / hop):max(int(n[1] * sr / hop), int(n[0] * sr / hop) + 1)].max() >= QUIET_DB]
    if len(kept) < len(notes):
        print(f"{len(notes) - len(kept)} notas descartadas por sonar a menos de {QUIET_DB:.0f} dB del pico")
    return kept


def merge_legato(notes):
    """Une fragmentos seguidos de la misma nota (vibrato, sílabas cortadas)."""
    merged = []
    for note in notes:
        last = merged[-1] if merged else None
        if last and last[2] == note[2] and note[0] - last[1] < LEGATO_GAP:
            merged[-1] = (last[0], max(last[1], note[1]), last[2], max(last[3], note[3]))
        else:
            merged.append(note)
    return merged


def snap(beat: float, subdivision: int) -> float:
    return round(beat * subdivision) / subdivision


def onset_lag(beats: np.ndarray) -> float:
    """Cuánto llegan tarde en promedio los ataques respecto a la rejilla de semicorcheas
    (la voz suele ir un poco detrás del ritmo y la transcripción agrega su propio retraso)."""
    return float(np.median(beats - np.round(beats * 4) / 4))


def choose_grids(beats: np.ndarray) -> dict[int, int]:
    """Rejilla por tiempo: tresillos solo si el tiempo tiene 2 notas o más y encajan
    claramente mejor en tresillo; si no, semicorcheas. Un ataque un poco corrido cae
    cerca de ambas rejillas, y los tresillos falsos son peores que una semicorchea."""
    groups: dict[int, list[float]] = {}
    for beat in beats:
        groups.setdefault(math.floor(beat + 1 / 8), []).append(beat)
    grids = {}
    for whole, members in groups.items():
        error = {sub: sum(abs(b - snap(b, sub)) for b in members) for sub in GRIDS}
        is_triplet = len(members) >= 2 and error[3] < TRIPLET_BIAS * error[4]
        grids[whole] = 3 if is_triplet else 4
    return grids


def quantize(notes, grid: BeatGrid, min_gap: float):
    """Una nota por posición de la rejilla (la más fuerte), separadas al menos min_gap tiempos."""
    starts = np.array([grid.beat_at(start) for start, *_ in notes])
    lag = onset_lag(starts)
    print(f"ataques corridos {lag * grid.ibi * 1000:+.0f} ms en promedio; se compensa")
    starts -= lag
    grids = choose_grids(starts)
    by_beat = {}
    for (start, end, pitch, amp), raw in zip(notes, starts):
        subdivision = grids[math.floor(raw + 1 / 8)]
        beat = snap(raw, subdivision)
        length = max(snap(grid.beat_at(end) - lag, subdivision) - beat, 1 / 4)
        if beat not in by_beat or amp > by_beat[beat][3]:
            by_beat[beat] = (beat, length, pitch, amp)
    kept = []
    for note in sorted(by_beat.values()):
        if kept and note[0] - kept[-1][0] < min_gap - 1e-6:
            if note[3] > kept[-1][3]:
                kept[-1] = note
            continue
        kept.append(note)
    return kept


def varlen(value: int) -> bytes:
    out = [value & 0x7F]
    value >>= 7
    while value:
        out.insert(0, (value & 0x7F) | 0x80)
        value >>= 7
    return bytes(out)


def write_midi(path: Path, notes, grid: BeatGrid):
    def tempo_event(seconds_per_beat: float) -> bytes:
        return b"\xff\x51\x03" + round(seconds_per_beat * 1_000_000).to_bytes(3, "big")

    events = [(0, 0, b"\xff\x58\x04\x04\x02\x18\x08"), (0, 0, tempo_event(grid.pickup)),
              (grid.anchor_beat * TPQ, 0, tempo_event(grid.ibi))]
    for beat, length, pitch, _ in notes:
        events.append((round(beat * TPQ), 2, bytes([0x90, pitch, 100])))
        events.append((round((beat + length) * TPQ), 1, bytes([0x80, pitch, 0])))
    events.sort()
    track, last = b"", 0
    for tick, _, data in events:
        track += varlen(tick - last) + data
        last = tick
    track += b"\x00\xff\x2f\x00"
    path.write_bytes(b"MThd" + struct.pack(">IHHH", 6, 0, 1, TPQ)
                     + b"MTrk" + struct.pack(">I", len(track)) + track)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("folder", type=Path, help="carpeta de la canción (con song.json)")
    parser.add_argument("--min-gap", type=float, default=0.25,
                        help="tiempos mínimos entre notas; más alto = canción más fácil (0.5 = corcheas)")
    args = parser.parse_args()

    info = json.loads((args.folder / "song.json").read_text())
    if "lead" not in info:
        raise SystemExit("song.json no tiene 'lead': hace falta la melodía separada para transcribirla")
    ibi, phase = measure_tempo(args.folder / info["audio"])
    grid = BeatGrid(ibi, phase)
    lead = args.folder / info["lead"]
    raw = merge_legato(drop_quiet(transcribe(lead), lead))
    notes = quantize(raw, grid, args.min_gap)
    write_midi(args.folder / "lead.mid", notes, grid)
    seconds = ibi * (notes[-1][0] - notes[0][0]) if len(notes) > 1 else 1.0
    print(f"{len(raw)} notas transcritas -> {len(notes)} en lead.mid ({len(notes) / seconds:.2f} notas/s)")


if __name__ == "__main__":
    main()
