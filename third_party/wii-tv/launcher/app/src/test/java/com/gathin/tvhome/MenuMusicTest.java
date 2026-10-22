package com.gathin.tvhome;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;

import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;

public class MenuMusicTest {
    @Rule public TemporaryFolder tmp = new TemporaryFolder();

    /** A WAV file: fmt, an optional odd-sized LIST chunk, an optional smpl loop (end inclusive), then data. */
    private File wav(int format, int channels, int rate, int bits, int frames, long[] loop, boolean list)
            throws IOException {
        int data = frames * channels * bits / 8;
        ByteBuffer b = ByteBuffer.allocate(12 + 24 + (list ? 12 : 0) + (loop != null ? 68 : 0) + 8 + data)
                .order(ByteOrder.LITTLE_ENDIAN);
        b.put("RIFF".getBytes(StandardCharsets.US_ASCII)).putInt(b.capacity() - 8)
                .put("WAVE".getBytes(StandardCharsets.US_ASCII));
        b.put("fmt ".getBytes(StandardCharsets.US_ASCII)).putInt(16).putShort((short) format)
                .putShort((short) channels).putInt(rate).putInt(rate * channels * bits / 8)
                .putShort((short) (channels * bits / 8)).putShort((short) bits);
        if (list) b.put("LIST".getBytes(StandardCharsets.US_ASCII)).putInt(3).put(new byte[] {1, 2, 3, 0});
        if (loop != null) {
            b.put("smpl".getBytes(StandardCharsets.US_ASCII)).putInt(60);
            for (int i = 0; i < 7; i++) b.putInt(0);
            b.putInt(1).putInt(0).putInt(0).putInt(0).putInt((int) loop[0]).putInt((int) loop[1]).putInt(0).putInt(0);
        }
        b.put("data".getBytes(StandardCharsets.US_ASCII)).putInt(data);
        File f = tmp.newFile();
        try (FileOutputStream out = new FileOutputStream(f)) {
            out.write(b.array());
        }
        return f;
    }

    @Test
    public void readsTheLoopFromTheSmplChunk() throws IOException {
        MenuMusic.Wav w = MenuMusic.Wav.read(wav(1, 2, 44100, 16, 1000, new long[] {100, 899}, false));
        assertNotNull(w);
        assertEquals(44100, w.rate);
        assertEquals(2, w.channels);
        assertEquals(1000, w.frames);
        assertEquals(12 + 24 + 68 + 8, w.dataOffset);
        assertEquals(100, w.loopStart);
        assertEquals(900, w.loopEnd);
    }

    @Test
    public void withoutALoopTheWholeFileRepeats() throws IOException {
        MenuMusic.Wav w = MenuMusic.Wav.read(wav(1, 1, 32000, 16, 500, null, false));
        assertEquals(0, w.loopStart);
        assertEquals(500, w.loopEnd);
        assertEquals(1, w.channels);
    }

    @Test
    public void aLoopPastTheSamplesIsIgnored() throws IOException {
        MenuMusic.Wav w = MenuMusic.Wav.read(wav(1, 2, 44100, 16, 1000, new long[] {500, 2000}, false));
        assertEquals(0, w.loopStart);
        assertEquals(1000, w.loopEnd);
    }

    @Test
    public void skipsOddSizedChunksAndTheirPadding() throws IOException {
        MenuMusic.Wav w = MenuMusic.Wav.read(wav(1, 2, 44100, 16, 10, null, true));
        assertEquals(12 + 24 + 12 + 8, w.dataOffset);
        assertEquals(10, w.frames);
    }

    @Test
    public void refusesWhatItCannotStream() throws IOException {
        assertNull(MenuMusic.Wav.read(wav(1, 2, 44100, 8, 1000, null, false)));
        assertNull(MenuMusic.Wav.read(wav(3, 2, 44100, 16, 1000, null, false)));
        assertNull(MenuMusic.Wav.read(wav(1, 6, 44100, 16, 1000, null, false)));
        assertNull(MenuMusic.Wav.read(wav(1, 2, 44100, 16, 0, null, false)));
        File junk = tmp.newFile();
        try (FileOutputStream out = new FileOutputStream(junk)) {
            out.write("not a wave file at all".getBytes(StandardCharsets.US_ASCII));
        }
        assertNull(MenuMusic.Wav.read(junk));
    }
}
