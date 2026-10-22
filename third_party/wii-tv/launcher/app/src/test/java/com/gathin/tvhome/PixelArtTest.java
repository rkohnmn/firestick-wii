package com.gathin.tvhome;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;

import org.junit.Test;

public class PixelArtTest {

    @Test
    public void initialSkipsAccentsDigitsAndMarks() {
        assertEquals('P', PixelArt.initial("Pokémon"));
        assertEquals('E', PixelArt.initial("¡Él 2!"));
        assertEquals('Z', PixelArt.initial("007 zona"));
        assertEquals(0, PixelArt.initial("1942"));
    }

    @Test
    public void fontTextOnlyTakesWhatTheFontDraws() {
        assertEquals("JUEGOS", PixelArt.fontText("Juegos"));
        assertEquals("MIS JUEGOS", PixelArt.fontText(" Mis juegos "));
        assertEquals("ACAO", PixelArt.fontText("Ação"));
        assertNull(PixelArt.fontText("Games 2"));
        assertNull(PixelArt.fontText("ゲーム"));
        assertNull(PixelArt.fontText(""));
    }

    @Test
    public void mixBlendsEachChannel() {
        assertEquals(0xFF808080, PixelArt.mix(0xFF000000, 0xFFFFFFFF, 0.5f));
        assertEquals(0xFF3F7F00, PixelArt.mix(0xFF7EFE00, 0xFF000000, 0.5f));
        assertEquals(0xFF000000, PixelArt.mix(0xFF000000, 0xFFFFFFFF, 0f));
        assertEquals(0xFFFFFFFF, PixelArt.mix(0xFF000000, 0xFFFFFFFF, 1f));
    }
}
