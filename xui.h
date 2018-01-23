#ifndef XUI_H
#define XUI_H

#include "xui_gfx.h"
#include <inttypes.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef unsigned int xid;

#ifdef XID_BASE
#define XID (__LINE__ + (XID_BASE))
#else
#define XID (__LINE__)
#endif

enum xui_mouse_buttons
{
    MOUSE_LEFT = 0x1,
    MOUSE_MIDDLE = 0x2,
    MOUSE_RIGHT = 0x4,
};

typedef struct xui_state
{
    xui_gfx* gfx;
    xid over_widget;
    xid hover_widget;
    xid pressed_widget;

    int mouse_x;
    int mouse_y;
    int mouse_buttons_state;
    int mouse_buttons_down_this_frame;
    int mouse_buttons_up_this_frame;
} xui_state;

extern xui_state* xui;

void xui_init(xui_gfx* gfx);
void xui_shutdown(void);

void xui_begin_frame(void);
bool xui_label_button(xid id, const char* label, int x, int y);

#ifdef __cplusplus
}
#endif

#endif // XUI_H

#ifdef XUI_IMPLEMENTATION

xui_state* xui = NULL;

void xui_init(xui_gfx* gfx)
{
    xui = (xui_state*)malloc(sizeof(xui_state));
    memset(xui, 0x00, sizeof(xui_state));
    xui->gfx = gfx;
}

void xui_shutdown()
{
    free(xui);
    xui = NULL;
}

void xui_begin_frame()
{
    xui->mouse_buttons_down_this_frame = 0;
    xui->mouse_buttons_up_this_frame = 0;
    xui->hover_widget = xui->over_widget;
    xui->over_widget = 0;

    if((xui->mouse_buttons_state & MOUSE_LEFT) == 0)
        xui->pressed_widget = 0;
}

static bool _xui_is_over_rect(int x, int y, int w, int h)
{
    int mx = xui->mouse_x;
    int my = xui->mouse_y;
    return (mx >= x && mx < x + w && my >= y && my < y + h);
}

bool xui_button(xid id, int x, int y, int w, int h)
{
    bool over = _xui_is_over_rect(x,y,w,h);

    bool clicked = false;
    if(over)
    {
        xui->over_widget = id;
        if(xui->mouse_buttons_down_this_frame & MOUSE_LEFT)
            xui->pressed_widget = id;

        if(xui->pressed_widget == id && xui->hover_widget == id && xui->mouse_buttons_up_this_frame & MOUSE_LEFT)
            clicked = true;
    }

    int normal_col = 0xffa0a0a0;
    int hover_col = 0xfff0a0a0;
    int pressed_col = 0xffffffff;
    int col = normal_col;
    if(xui->pressed_widget == id && xui->hover_widget == id)
        col = pressed_col;
    else if(xui->hover_widget == id)
        col = hover_col;

    xui_draw_rect(xui->gfx, x,y,w,h, col);
    return clicked;
}

bool xui_label_button(xid id, const char* label, int x, int y)
{
    int w,h;
    xui_string_bounds(xui->gfx, label, &w, &h);

    int padding = 4;
    w += 2*padding;
    h += 2*padding;

    bool clicked = xui_button(id, x,y, w,h);

    xui_draw_string(xui->gfx, x + padding, y + padding, 0xff000000, label);

    return clicked;
}

#undef XUI_IMPLEMENTATION
#endif
