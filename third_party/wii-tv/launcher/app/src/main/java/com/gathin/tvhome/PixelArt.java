package com.gathin.tvhome;

import android.graphics.Bitmap;

import java.text.Normalizer;
import java.util.Locale;

/** Small pixel-art bitmaps for the Games channel: sprites from text rows, words in a 5 x 7 font, cartridges. */
final class PixelArt {
    private PixelArt() {}

    /** Rows of A-Z, 5 bits each, leftmost pixel in bit 4. */
    private static final int[][] FONT = {
            {0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11}, {0x1E, 0x11, 0x11, 0x1E, 0x11, 0x11, 0x1E},
            {0x0E, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0E}, {0x1E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x1E},
            {0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x1F}, {0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10},
            {0x0E, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0F}, {0x11, 0x11, 0x11, 0x1F, 0x11, 0x11, 0x11},
            {0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E}, {0x07, 0x02, 0x02, 0x02, 0x02, 0x12, 0x0C},
            {0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11}, {0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1F},
            {0x11, 0x1B, 0x15, 0x15, 0x11, 0x11, 0x11}, {0x11, 0x11, 0x19, 0x15, 0x13, 0x11, 0x11},
            {0x0E, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E}, {0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10},
            {0x0E, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0D}, {0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11},
            {0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E}, {0x1F, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04},
            {0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0E}, {0x11, 0x11, 0x11, 0x11, 0x11, 0x0A, 0x04},
            {0x11, 0x11, 0x11, 0x15, 0x15, 0x15, 0x0A}, {0x11, 0x11, 0x0A, 0x04, 0x0A, 0x11, 0x11},
            {0x11, 0x11, 0x0A, 0x04, 0x04, 0x04, 0x04}, {0x1F, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1F},
    };

    /**
     * A sprite from rows of characters, one pixel each; {@code colors} pairs a character with its colour
     * ("k", 0xFF2B3A55, ...). Any other character is transparent.
     */
    static Bitmap sprite(String[] rows, Object... colors) {
        int w = 0;
        for (String r : rows) w = Math.max(w, r.length());
        int[] px = new int[w * rows.length];
        for (int y = 0; y < rows.length; y++) {
            for (int x = 0; x < rows[y].length(); x++) {
                char ch = rows[y].charAt(x);
                for (int i = 0; i + 1 < colors.length; i += 2) {
                    if (((String) colors[i]).charAt(0) == ch) {
                        px[y * w + x] = (Integer) colors[i + 1];
                        break;
                    }
                }
            }
        }
        return Bitmap.createBitmap(px, w, rows.length, Bitmap.Config.ARGB_8888);
    }

    /** The word in capitals without accents, or null when the font has no glyph for one of its letters. */
    static String fontText(String word) {
        String plain = Normalizer.normalize(word, Normalizer.Form.NFD).replaceAll("\\p{M}", "")
                .toUpperCase(Locale.ROOT).trim();
        if (plain.isEmpty()) return null;
        for (int i = 0; i < plain.length(); i++) {
            char ch = plain.charAt(i);
            if (ch != ' ' && (ch < 'A' || ch > 'Z')) return null;
        }
        return plain;
    }

    static final int CART_W = 24, CART_H = 28;
    private static final int CART_OUTLINE = 0xFF3E444E, CART_BODY = 0xFFB8BEC7, CART_LIGHT = 0xFFDDE1E6,
            CART_DARK = 0xFF8D949F;

    /** The first letter of the title the font can draw, accents dropped; 0 when it has none. */
    static char initial(String title) {
        String plain = Normalizer.normalize(title, Normalizer.Form.NFD).replaceAll("\\p{M}", "")
                .toUpperCase(Locale.ROOT);
        for (int i = 0; i < plain.length(); i++) {
            char ch = plain.charAt(i);
            if (ch >= 'A' && ch <= 'Z') return ch;
        }
        return 0;
    }

    /**
     * A game cartridge, CART_W x CART_H: a grey shell with grip grooves along the top, a label in the game's
     * colour carrying the title's initial, and the gold contacts showing under it.
     */
    static Bitmap cartridge(int color, String title) {
        int w = CART_W, h = CART_H, shellEnd = h - 4;
        boolean[] in = new boolean[w * h];
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                boolean corner = (x == 0 || x == w - 1) && (y == 0 || y == shellEnd);
                boolean shell = y <= shellEnd && !corner;
                boolean contacts = y > shellEnd && x >= 4 && x <= w - 5;
                in[y * w + x] = shell || contacts;
            }
        }
        int[] px = new int[w * h];
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                if (!in[y * w + x]) continue;
                boolean edge = x == 0 || y == 0 || x == w - 1 || y == h - 1 || !in[y * w + x - 1]
                        || !in[y * w + x + 1] || !in[(y - 1) * w + x] || !in[(y + 1) * w + x];
                int c;
                if (edge) c = CART_OUTLINE;
                else if (y > shellEnd) c = x % 2 == 1 ? (y == h - 2 ? 0xFFC9952A : 0xFFF2C14E) : 0xFF6B5320;
                else if (y == shellEnd) c = CART_OUTLINE;
                else if (x == 1 || y == 1) c = CART_LIGHT;
                else if (x == w - 2 || y == shellEnd - 1) c = CART_DARK;
                else c = CART_BODY;
                px[y * w + x] = c;
            }
        }
        for (int x = 3; x <= w - 4; x++) {
            px[2 * w + x] = CART_DARK;
            px[3 * w + x] = CART_LIGHT;
            px[4 * w + x] = CART_DARK;
        }
        // The label, sunk into the shell: shadow along its top and left, light along its bottom and right.
        for (int y = 6; y <= 19; y++) {
            for (int x = 3; x <= w - 4; x++) {
                int c;
                if (y == 6 || x == 3) c = CART_DARK;
                else if (y == 19 || x == w - 4) c = CART_LIGHT;
                else if (y == 7) c = mix(color, 0xFFFFFFFF, 0.35f);
                else if (y == 17) c = mix(color, 0xFFFFFFFF, 0.5f);
                else if (y == 18) c = mix(color, 0xFF000000, 0.25f);
                else c = color;
                px[y * w + x] = c;
            }
        }
        char letter = initial(title);
        if (letter != 0) glyph(px, w, 9, 9, letter, 0xFFFFFFFF, mix(color, 0xFF000000, 0.45f));
        return Bitmap.createBitmap(px, w, h, Bitmap.Config.ARGB_8888);
    }

    /** One letter at (x0, y0) with a one-pixel outline round it. */
    private static void glyph(int[] px, int w, int x0, int y0, char ch, int fill, int outline) {
        int[] g = FONT[ch - 'A'];
        for (int y = -1; y <= 7; y++) {
            for (int x = -1; x <= 5; x++) {
                int at = (y0 + y) * w + x0 + x;
                if (on(g, x, y)) {
                    px[at] = fill;
                    continue;
                }
                for (int dy = -1; dy <= 1 && px[at] != outline; dy++) {
                    for (int dx = -1; dx <= 1; dx++) {
                        if (on(g, x + dx, y + dy)) {
                            px[at] = outline;
                            break;
                        }
                    }
                }
            }
        }
    }

    private static boolean on(int[] g, int x, int y) {
        return x >= 0 && y >= 0 && x < 5 && y < 7 && (g[y] & (0x10 >> x)) != 0;
    }

    static int mix(int a, int b, float t) {
        int r = Math.round(((a >> 16) & 0xFF) * (1 - t) + ((b >> 16) & 0xFF) * t);
        int g = Math.round(((a >> 8) & 0xFF) * (1 - t) + ((b >> 8) & 0xFF) * t);
        int bl = Math.round((a & 0xFF) * (1 - t) + (b & 0xFF) * t);
        return 0xFF000000 | (r << 16) | (g << 8) | bl;
    }
    /**
     * The word in the 5 x 7 font: a fill with a lighter top row, a one-pixel outline and a drop shadow one pixel
     * down. {@code text} must come from {@link #fontText}.
     */
    static Bitmap word(String text, int fill, int top, int outline, int shadow) {
        int w = 0;
        for (int i = 0; i < text.length(); i++) w += text.charAt(i) == ' ' ? 4 : 6;
        w -= 1;
        int bw = w + 2, bh = 7 + 3;
        boolean[] on = new boolean[bw * bh];
        int[] row = new int[bw * bh];
        int x0 = 1;
        for (int i = 0; i < text.length(); i++) {
            char ch = text.charAt(i);
            if (ch == ' ') {
                x0 += 4;
                continue;
            }
            int[] g = FONT[ch - 'A'];
            for (int y = 0; y < 7; y++) {
                for (int x = 0; x < 5; x++) {
                    if ((g[y] & (0x10 >> x)) == 0) continue;
                    int at = (y + 1) * bw + x0 + x;
                    on[at] = true;
                    row[at] = y;
                }
            }
            x0 += 6;
        }
        int[] px = new int[bw * bh];
        for (int y = 0; y < bh; y++) {
            for (int x = 0; x < bw; x++) {
                int at = y * bw + x;
                if (on[at]) {
                    px[at] = row[at] == 0 ? top : fill;
                } else if (near(on, bw, bh, x, y)) {
                    px[at] = outline;
                } else if (y > 0 && near(on, bw, bh, x, y - 1)) {
                    px[at] = shadow;
                }
            }
        }
        return Bitmap.createBitmap(px, bw, bh, Bitmap.Config.ARGB_8888);
    }

    private static boolean near(boolean[] on, int w, int h, int x, int y) {
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                int xx = x + dx, yy = y + dy;
                if (xx >= 0 && yy >= 0 && xx < w && yy < h && on[yy * w + xx]) return true;
            }
        }
        return false;
    }
}
