package com.gathin.tvhome;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.ColorFilter;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;

/**
 * The Games channel's picture: a pixel-art meadow scrolling past a little blue runner who hops over rocks for
 * the gems above them, under the channel's name in bouncing letters. ROWS art pixels fill the height, so the
 * same scene draws the menu tile and the channel's header; only the width shows more or less of the meadow.
 */
final class PixelScene {
    static final int ROWS = 60;
    /** The row of the grass top; the runner's feet, the rocks and the flowers stand on the row above. */
    private static final int GROUND = 52;
    /** Art pixels per second the ground moves; the layers behind move slower. */
    private static final float SPEED = 16f;
    private static final int SPACING = 64;
    private static final int FIRST_ROCK = 40;
    private static final float JUMP_H = 10f;
    private static final float JUMP_HALF = 16f;
    private static final int TITLE_SCALE = 2;
    /** Speeds and widths line up after this long, so the loop restarts without a jump. */
    private static final long LOOP_MS = 3_600_000L;
    private static final int[] SKY = {0xFF6EC3EE, 0xFF84CDF1, 0xFF9AD6F4, 0xFFB0DFF6, 0xFFC6E8F9, 0xFFDAF1FB};

    private static Bitmap runA, runB, jump, gemA, gemB, sparkA, sparkB, rock, cloud, cloudSmall, hillsFar,
            hillsNear, ground;
    private static Bitmap[] flowers;

    private final Bitmap[] letters;
    private final int[] letterX;
    private final int titleW;
    private final String label;
    private final Paint px = new Paint();
    private final Paint flat = new Paint();
    private final Paint text = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF dst = new RectF();

    PixelScene(String label, Typeface face) {
        this.label = label;
        loadSprites();
        // Paint filters bitmaps by default since Android 9; the art has to stay square pixels.
        px.setFilterBitmap(false);
        px.setAntiAlias(false);
        text.setTypeface(face);
        text.setTextAlign(Paint.Align.CENTER);
        String word = PixelArt.fontText(label);
        if (word == null) {
            letters = null;
            letterX = null;
            titleW = 0;
            return;
        }
        int n = 0;
        for (int i = 0; i < word.length(); i++) if (word.charAt(i) != ' ') n++;
        letters = new Bitmap[n];
        letterX = new int[n];
        int x = 0, k = 0;
        for (int i = 0; i < word.length(); i++) {
            char ch = word.charAt(i);
            if (ch == ' ') {
                x += 4;
                continue;
            }
            int c = GameList.PALETTE[k % GameList.PALETTE.length];
            letters[k] = PixelArt.word(String.valueOf(ch), c, PixelArt.mix(c, 0xFFFFFFFF, 0.45f), 0xFFFFFFFF,
                    0x8022324A);
            letterX[k++] = x;
            x += 6;
        }
        titleW = x + 1;
    }

    void setColorFilter(ColorFilter filter) {
        px.setColorFilter(filter);
        flat.setColorFilter(filter);
    }

    /**
     * The scene in (0, 0, w, h) of the canvas at uptime {@code ms}: the runner stands at {@code heroAt} of the
     * width, the name's top {@code titleTop} art pixels down.
     */
    void draw(Canvas c, float w, float h, long ms, float heroAt, float titleTop) {
        float p = h / ROWS;
        float wa = w / p;
        float t = (ms % LOOP_MS) / 1000f;
        float scroll = t * SPEED;
        int save = c.save();
        c.clipRect(0, 0, w, h);
        c.scale(p, p);

        for (int i = 0; i < SKY.length; i++) {
            flat.setColor(SKY[i]);
            c.drawRect(0, i * 9, wa, i == SKY.length - 1 ? GROUND : (i + 1) * 9, flat);
        }
        float drift = t * 2f;
        for (float bx = -(drift % 120f); bx < wa; bx += 120f) {
            c.drawBitmap(cloud, bx + 8f, 5f, px);
            c.drawBitmap(cloudSmall, bx + 62f, 15f, px);
            c.drawBitmap(cloudSmall, bx + 95f, 3f, px);
        }
        strip(c, hillsFar, GROUND - hillsFar.getHeight(), wa, t * 4f);
        strip(c, hillsNear, GROUND - hillsNear.getHeight(), wa, t * 8f);
        strip(c, ground, GROUND - 1, wa, scroll);

        float heroX = Math.round(wa * heroAt);
        float heroMid = heroX + 6f;
        int kFrom = (int) Math.floor((scroll - 60f - FIRST_ROCK) / SPACING);
        int kTo = (int) Math.ceil((scroll + wa - FIRST_ROCK) / SPACING);
        for (int k = kFrom; k <= kTo; k++) {
            float x = FIRST_ROCK + k * (float) SPACING - scroll;
            int f = Math.floorMod(k, flowers.length);
            c.drawBitmap(flowers[f], x + 28f, GROUND - 4f, px);
            c.drawBitmap(flowers[(f + 1) % flowers.length], x + 43f, GROUND - 4f, px);
            c.drawBitmap(rock, x, GROUND - 6f, px);
            float gem = x + 4.5f;
            float past = heroMid - gem;
            if (past < 0f) {
                int spin = Math.floorMod((int) (t * 6f) + k, 3);
                c.drawBitmap(spin == 2 ? gemB : gemA, gem - 3.5f, 23f, px);
            } else if (past < 14f) {
                c.drawBitmap(past < 7f ? sparkA : sparkB, gem - 2.5f, 24f, px);
            }
        }

        float world = heroMid + scroll;
        int near = Math.round((world - FIRST_ROCK - 4.5f) / SPACING);
        float u = (world - (FIRST_ROCK + 4.5f + near * (float) SPACING)) / JUMP_HALF;
        float lift = Math.abs(u) < 1f ? JUMP_H * (1f - u * u) : 0f;
        flat.setColor(0x30000000);
        float sw = 8f - lift * 0.4f;
        c.drawRect(heroMid - sw / 2f, GROUND, heroMid + sw / 2f, GROUND + 1, flat);
        Bitmap hero = lift > 0.5f ? jump : (((int) (scroll / 3f)) % 2 == 0 ? runA : runB);
        c.drawBitmap(hero, heroX, Math.round(GROUND - 12 - lift), px);

        if (letters != null) {
            float x0 = Math.round((wa - titleW * TITLE_SCALE) / 2f);
            for (int i = 0; i < letters.length; i++) {
                float bob = Math.round((float) Math.sin(t * 3.4f - i * 0.7f) * 1.2f);
                float lx = x0 + letterX[i] * TITLE_SCALE, ly = titleTop + bob;
                dst.set(lx, ly, lx + letters[i].getWidth() * TITLE_SCALE, ly + letters[i].getHeight() * TITLE_SCALE);
                c.drawBitmap(letters[i], null, dst, px);
            }
        }
        c.restoreToCount(save);

        if (letters == null) {
            // A name the pixel font cannot spell is written in the menu's typeface instead.
            text.setTextSize(h * 0.17f);
            text.setStyle(Paint.Style.STROKE);
            text.setStrokeWidth(h * 0.03f);
            text.setColor(0xFF22324A);
            c.drawText(label, w / 2f, h * 0.27f, text);
            text.setStyle(Paint.Style.FILL);
            text.setColor(0xFFFFFFFF);
            c.drawText(label, w / 2f, h * 0.27f, text);
        }
    }

    private void strip(Canvas c, Bitmap b, float y, float wa, float shift) {
        int bw = b.getWidth();
        for (float x = -(shift % bw); x < wa; x += bw) c.drawBitmap(b, x, y, px);
    }

    private static synchronized void loadSprites() {
        if (runA != null) return;
        Object[] blob = {"k", 0xFF1D5A80, "b", 0xFF3FC0EC, "l", 0xFFB5ECFC, "w", 0xFFFFFFFF, "p", 0xFFFF9DB8};
        String[] body = {
                "...kkkkkk...",
                ".kkbbbbbbkk.",
                ".kbllbbbbbk.",
                "kblbbbbbbbbk",
                "kbbbbbbwwbwk",
                "kbbbbbbwkbkk",
                "kbbbbbbbbbbk",
                "kbbbbbpbbbpk",
                "kbbbbbbbbbbk",
                ".kbbbbbbbbk.",
        };
        runA = PixelArt.sprite(with(body, "..kkkkkkkk..", "..kk....kk.."), blob);
        runB = PixelArt.sprite(with(body, "..kkkkkkkk..", "....kkkk...."), blob);
        jump = PixelArt.sprite(with(body, ".kkkkkkkkkk.", "kk........kk"), blob);
        Object[] gold = {"k", 0xFF9A5B00, "w", 0xFFFFFBD6, "y", 0xFFFFD02E, "o", 0xFFF29D16};
        gemA = PixelArt.sprite(new String[] {
                "..kkk..",
                ".kwyyk.",
                "kwyyyok",
                "kyyyyok",
                ".kyyok.",
                "..kok..",
                "...k...",
        }, gold);
        gemB = PixelArt.sprite(new String[] {
                "...k...",
                "..kwk..",
                ".kwyok.",
                ".kyyok.",
                "..kyk..",
                "..kok..",
                "...k...",
        }, gold);
        Object[] spark = {"w", 0xFFFFFFFF, "y", 0xFFFFE680};
        sparkA = PixelArt.sprite(new String[] {"..w..", "..y..", "wy.yw", "..y..", "..w.."}, spark);
        sparkB = PixelArt.sprite(new String[] {".....", "..y..", ".y.y.", "..y..", "....."}, spark);
        rock = PixelArt.sprite(new String[] {
                "...kkk...",
                "..kllgk..",
                ".klggggk.",
                "kgggggddk",
                "kgggdgddk",
                "kkkkkkkkk",
        }, "k", 0xFF56606B, "l", 0xFFE0E5EA, "g", 0xFFAFB8C2, "d", 0xFF8A94A0);
        Object[] sky = {"w", 0xFFFFFFFF, "s", 0xFFD3ECF8};
        cloud = PixelArt.sprite(new String[] {
                "......wwww..........",
                "....wwwwwwww..www...",
                "..wwwwwwwwwwwwwwwww.",
                ".wwwwwwwwwwwwwwwwwww",
                "wwwwwwwwwwwwwwwwwwww",
                "wwwwwwwwwwwwwwwwwwww",
                ".ssssssssssssssssss.",
        }, sky);
        cloudSmall = PixelArt.sprite(new String[] {
                "...wwww.....",
                ".wwwwwwwww..",
                "wwwwwwwwwwww",
                "wwwwwwwwwwww",
                ".ssssssssss.",
        }, sky);
        String[] flower = {".r.", "rcr", ".r.", ".g."};
        flowers = new Bitmap[3];
        int[] petals = {0xFFFF6B6B, 0xFFFFFFFF, 0xFFFF9EDB};
        for (int i = 0; i < 3; i++) {
            flowers[i] = PixelArt.sprite(flower, "r", petals[i], "c", 0xFFFFD43B, "g", 0xFF3E9A3A);
        }
        hillsFar = hills(96, 20, 10, 4, 2.5, 3, 1.3, 0xFFA9DDB8, 0xFFC9EDD2, 0xFF9BD3AB);
        hillsNear = hills(64, 13, 6, 3, 1.5, 2, 0.4, 0xFF71C68B, 0xFF95D9A6, 0xFF63B97E);
        ground = groundStrip();
    }

    private static String[] with(String[] top, String... more) {
        String[] rows = new String[top.length + more.length];
        System.arraycopy(top, 0, rows, 0, top.length);
        System.arraycopy(more, 0, rows, top.length, more.length);
        return rows;
    }

    /** A strip of rolling hills that repeats every w pixels. */
    private static Bitmap hills(int w, int h, double base, double a1, double a2, int f2, double phase, int fill,
            int top, int dot) {
        int[] px = new int[w * h];
        for (int x = 0; x < w; x++) {
            double v = base + a1 * Math.sin(2 * Math.PI * x / w) + a2 * Math.sin(2 * Math.PI * f2 * x / w + phase);
            int y0 = Math.max(0, h - (int) Math.round(v));
            for (int y = y0; y < h; y++) {
                int c = fill;
                if (y == y0) c = top;
                else if (y > y0 + 1 && (x * 7 + y * 13) % 11 == 0) c = dot;
                px[y * w + x] = c;
            }
        }
        return Bitmap.createBitmap(px, w, h, Bitmap.Config.ARGB_8888);
    }

    /** Grass blades, grass and earth, 32 pixels that repeat. */
    private static Bitmap groundStrip() {
        int w = 32, h = 9;
        int[] px = new int[w * h];
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                int c;
                if (y == 0) c = x % 4 == 1 || x % 16 == 10 ? 0xFF6CC653 : 0;
                else if (y == 1) c = 0xFF8BDB6A;
                else if (y == 2) c = 0xFF63C04E;
                else if (y == 3) c = x % 4 < 2 ? 0xFF4FA63F : 0xFF63C04E;
                else {
                    int hsh = (x * 31 + y * 17) % 23;
                    c = hsh == 0 ? 0xFFB57E45 : hsh == 7 ? 0xFFE4B27C : 0xFFD29A5F;
                }
                px[y * w + x] = c;
            }
        }
        return Bitmap.createBitmap(px, w, h, Bitmap.Config.ARGB_8888);
    }
}
