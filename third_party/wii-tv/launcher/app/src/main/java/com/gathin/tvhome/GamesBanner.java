package com.gathin.tvhome;

import android.graphics.Canvas;
import android.graphics.ColorFilter;
import android.graphics.PixelFormat;
import android.graphics.Rect;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.os.SystemClock;

/** The Games channel's tile in the channel menu: its pixel meadow, always moving. */
final class GamesBanner extends Drawable implements WiiMenuView.LiveArt {
    private final PixelScene scene;

    GamesBanner(String label, Typeface face) {
        scene = new PixelScene(label, face);
    }

    @Override
    public boolean animating() {
        return true;
    }

    @Override
    public void draw(Canvas c) {
        Rect b = getBounds();
        int save = c.save();
        c.translate(b.left, b.top);
        scene.draw(c, b.width(), b.height(), SystemClock.uptimeMillis(), 0.2f, 1.5f);
        c.restoreToCount(save);
    }

    @Override
    public void setAlpha(int alpha) {
    }

    @Override
    public void setColorFilter(ColorFilter colorFilter) {
        scene.setColorFilter(colorFilter);
    }

    @Override
    public int getOpacity() {
        return PixelFormat.OPAQUE;
    }
}
