"""tools/music/add.py: the loop it cuts and the WAV files it writes, without a TV or ffmpeg.

Run from the repository root: python3 -m unittest discover -s tests -v
"""
from pathlib import Path
import array
import importlib.util
import io
import struct
import unittest
import wave


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("music_add", ROOT / "tools" / "music" / "add.py")
add = importlib.util.module_from_spec(spec)
spec.loader.exec_module(add)


def ramp(frames):
    """Stereo: the left channel counts frames up, the right one down, so every frame is told apart."""
    return array.array("h", [v for i in range(frames) for v in (i, -i)])


def chunks(data):
    out, at = {}, 12
    while at + 8 <= len(data):
        cid, size = data[at:at + 4], struct.unpack("<I", data[at + 4:at + 8])[0]
        out[cid] = data[at + 8:at + 8 + size]
        at += 8 + size + (size & 1)
    return out


class LoopTest(unittest.TestCase):
    def test_without_a_loop_the_whole_file_repeats(self):
        x = ramp(300)
        out, start, end = add.make_loop(x, 2, 100)
        self.assertEqual((start, end), (0, 300))
        self.assertEqual(out, x)

    def test_the_loop_end_fades_into_the_audio_before_its_start(self):
        x = ramp(6000)
        out, start, end = add.make_loop(x, 2, 1000, loop=(2.0, 5.0), crossfade=0.5)
        self.assertEqual((start, end), (2000, 5000))
        self.assertEqual(len(out), 5000 * 2)
        # Untouched up to the crossfade, then from the music's own end to just before the loop's start.
        self.assertEqual(out[4499 * 2], 4499)
        self.assertAlmostEqual(out[4500 * 2], 4500, delta=1)
        self.assertAlmostEqual(out[4999 * 2], 1999, delta=1)
        self.assertAlmostEqual(out[4999 * 2 + 1], -1999, delta=1)
        self.assertEqual(out[:4500 * 2], x[:4500 * 2])

    def test_the_crossfade_never_reaches_before_the_file(self):
        out, start, end = add.make_loop(ramp(6000), 2, 1000, loop=(0.1, 5.0), crossfade=1.0)
        self.assertEqual(start, 100)
        self.assertAlmostEqual(out[4999 * 2], 99, delta=1)
        self.assertEqual(out[4899 * 2], 4899)

    def test_a_loop_outside_the_music_is_refused(self):
        for loop in ((3.0, 2.0), (1.0, 99.0), (-1.0, 2.0), (2.0, 2.0)):
            with self.assertRaises(ValueError):
                add.make_loop(ramp(6000), 2, 1000, loop=loop)


class WavTest(unittest.TestCase):
    def test_reads_back_as_16_bit_pcm(self):
        x = ramp(500)
        data = add.wav_bytes(x, 2, 44100)
        with wave.open(io.BytesIO(data)) as w:
            self.assertEqual((w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()),
                             (2, 2, 44100, 500))
            self.assertEqual(w.readframes(500), x.tobytes())
        self.assertNotIn(b"smpl", chunks(data))

    def test_the_loop_goes_in_a_smpl_chunk_with_an_inclusive_end(self):
        data = add.wav_bytes(ramp(500), 2, 44100, loop=(100, 400))
        smpl = chunks(data)[b"smpl"]
        self.assertEqual(struct.unpack("<I", smpl[28:32])[0], 1)
        self.assertEqual(struct.unpack("<II", smpl[44:52]), (100, 399))
        with wave.open(io.BytesIO(data)) as w:
            self.assertEqual(w.getnframes(), 500)


if __name__ == "__main__":
    unittest.main()
