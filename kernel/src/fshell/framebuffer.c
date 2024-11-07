#include <fshell/framebuffer.h>
#include <kprintf>
#include <io.h>

const uint8_t font8x8[128][8] = {
    // ASCII 0 to 31: Control characters
    [0 ... 31] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
    // ASCII 32 ' '
    { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },
    // ASCII 33 '!'
    { 0x18, 0x3C, 0x3C, 0x18, 0x18, 0x00, 0x18, 0x00 },
    // ASCII 34 '"'
    { 0x36, 0x36, 0x12, 0x24, 0x00, 0x00, 0x00, 0x00 },
    // ASCII 35 '#'
    { 0x36, 0x36, 0x7F, 0x36, 0x7F, 0x36, 0x36, 0x00 },
    // ASCII 36 '$'
    { 0x18, 0x3E, 0x60, 0x3C, 0x06, 0x7C, 0x18, 0x00 },
    // ASCII 37 '%'
    { 0x66, 0x66, 0x0C, 0x18, 0x30, 0x66, 0x66, 0x00 },
    // ASCII 38 '&'
    { 0x1C, 0x36, 0x1C, 0x6E, 0x3B, 0x33, 0x6E, 0x00 },
    // ASCII 39 '''
    { 0x0C, 0x18, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00 },
    // ASCII 40 '('
    { 0x0C, 0x18, 0x30, 0x30, 0x30, 0x18, 0x0C, 0x00 },
    // ASCII 41 ')'
    { 0x30, 0x18, 0x0C, 0x0C, 0x0C, 0x18, 0x30, 0x00 },
    // ASCII 42 '*'
    { 0x00, 0x66, 0x3C, 0xFF, 0x3C, 0x66, 0x00, 0x00 },
    // ASCII 43 '+'
    { 0x00, 0x18, 0x18, 0x7E, 0x18, 0x18, 0x00, 0x00 },
    // ASCII 44 ','
    { 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x30 },
    // ASCII 45 '-'
    { 0x00, 0x00, 0x00, 0x7E, 0x00, 0x00, 0x00, 0x00 },
    // ASCII 46 '.'
    { 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00 },
    // ASCII 47 '/'
    { 0x06, 0x0C, 0x18, 0x30, 0x60, 0xC0, 0x80, 0x00 },
    // ASCII 48 '0'
    { 0x3C, 0x66, 0x6E, 0x76, 0x66, 0x66, 0x3C, 0x00 },
    // ASCII 49 '1'
    { 0x18, 0x38, 0x18, 0x18, 0x18, 0x18, 0x7E, 0x00 },
    // ASCII 50 '2'
    { 0x3C, 0x66, 0x06, 0x0C, 0x30, 0x60, 0x7E, 0x00 },
    // ASCII 51 '3'
    { 0x3C, 0x66, 0x06, 0x1C, 0x06, 0x66, 0x3C, 0x00 },
    // ASCII 52 '4'
    { 0x0C, 0x1C, 0x3C, 0x6C, 0x7E, 0x0C, 0x1E, 0x00 },
    // ASCII 53 '5'
    { 0x7E, 0x60, 0x7C, 0x06, 0x06, 0x66, 0x3C, 0x00 },
    // ASCII 54 '6'
    { 0x3C, 0x66, 0x60, 0x7C, 0x66, 0x66, 0x3C, 0x00 },
    // ASCII 55 '7'
    { 0x7E, 0x06, 0x0C, 0x18, 0x30, 0x30, 0x30, 0x00 },
    // ASCII 56 '8'
    { 0x3C, 0x66, 0x66, 0x3C, 0x66, 0x66, 0x3C, 0x00 },
    // ASCII 57 '9'
    { 0x3C, 0x66, 0x66, 0x3E, 0x06, 0x66, 0x3C, 0x00 },
    // ASCII 58 ':'
    { 0x00, 0x18, 0x18, 0x00, 0x00, 0x18, 0x18, 0x00 },
    // ASCII 59 ';'
    { 0x00, 0x18, 0x18, 0x00, 0x00, 0x18, 0x18, 0x30 },
    // ASCII 60 '<'
    { 0x0C, 0x18, 0x30, 0x60, 0x30, 0x18, 0x0C, 0x00 },
    // ASCII 61 '='
    { 0x00, 0x7E, 0x00, 0x00, 0x00, 0x7E, 0x00, 0x00 },
    // ASCII 62 '>'
    { 0x30, 0x18, 0x0C, 0x06, 0x0C, 0x18, 0x30, 0x00 },
    // ASCII 63 '?'
    { 0x3C, 0x66, 0x06, 0x1C, 0x30, 0x00, 0x30, 0x00 },
    // ASCII 64 '@'
    { 0x3C, 0x66, 0x6E, 0x6A, 0x6E, 0x60, 0x3C, 0x00 },
    // ASCII 65 'A'
    { 0x18, 0x3C, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x00 },
    // ASCII 66 'B'
    { 0x7C, 0x36, 0x36, 0x3C, 0x36, 0x36, 0x7C, 0x00 },
    // ASCII 67 'C'
    { 0x3C, 0x66, 0x60, 0x60, 0x60, 0x66, 0x3C, 0x00 },
    // ASCII 68 'D'
    { 0x78, 0x36, 0x36, 0x36, 0x36, 0x36, 0x78, 0x00 },
    // ASCII 69 'E'
    { 0x7E, 0x60, 0x60, 0x7C, 0x60, 0x60, 0x7E, 0x00 },
    // ASCII 70 'F'
    { 0x7E, 0x60, 0x60, 0x7C, 0x60, 0x60, 0x60, 0x00 },
    // ASCII 71 'G'
    { 0x3C, 0x66, 0x60, 0x6E, 0x66, 0x66, 0x3C, 0x00 },
    // ASCII 72 'H'
    { 0x66, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x66, 0x00 },
    // ASCII 73 'I'
    { 0x3C, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3C, 0x00 },
    // ASCII 74 'J'
    { 0x1E, 0x0C, 0x0C, 0x0C, 0x0C, 0x6C, 0x38, 0x00 },
    // ASCII 75 'K'
    { 0x66, 0x6C, 0x78, 0x70, 0x78, 0x6C, 0x66, 0x00 },
    // ASCII 76 'L'
    { 0x60, 0x60, 0x60, 0x60, 0x60, 0x60, 0x7E, 0x00 },
    // ASCII 77 'M'
    { 0x63, 0x77, 0x7F, 0x6B, 0x63, 0x63, 0x63, 0x00 },
    // ASCII 78 'N'
    { 0x66, 0x76, 0x7E, 0x6E, 0x66, 0x66, 0x66, 0x00 },
    // ASCII 79 'O'
    { 0x3C, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00 },
    // ASCII 80 'P'
    { 0x7C, 0x66, 0x66, 0x7C, 0x60, 0x60, 0x60, 0x00 },
    // ASCII 81 'Q'
    { 0x3C, 0x66, 0x66, 0x66, 0x6E, 0x6C, 0x36, 0x00 },
    // ASCII 82 'R'
    { 0x7C, 0x66, 0x66, 0x7C, 0x78, 0x6C, 0x66, 0x00 },
    // ASCII 83 'S'
    { 0x3C, 0x66, 0x60, 0x3C, 0x06, 0x66, 0x3C, 0x00 },
    // ASCII 84 'T'
    { 0x7E, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00 },
    // ASCII 85 'U'
    { 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x7E, 0x00 },
    // ASCII 86 'V'
    { 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x18, 0x00 },
    // ASCII 87 'W'
    { 0x63, 0x63, 0x63, 0x63, 0x6B, 0x7F, 0x36, 0x00 },
    // ASCII 88 'X'
    { 0x66, 0x66, 0x3C, 0x18, 0x3C, 0x66, 0x66, 0x00 },
    // ASCII 89 'Y'
    { 0x66, 0x66, 0x66, 0x3C, 0x18, 0x18, 0x18, 0x00 },
    // ASCII 90 'Z'
    { 0x7E, 0x06, 0x0C, 0x18, 0x30, 0x60, 0x7E, 0x00 },
    // ASCII 91 '['
    { 0x3C, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3C, 0x00 },
    // ASCII 92 '\'
    { 0xC0, 0x60, 0x30, 0x18, 0x0C, 0x06, 0x03, 0x00 },
    // ASCII 93 ']'
    { 0x3C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x3C, 0x00 },
    // ASCII 94 '^'
    { 0x18, 0x3C, 0x66, 0x42, 0x00, 0x00, 0x00, 0x00 },
    // ASCII 95 '_'
    { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF },
    // ASCII 96 '`'
    { 0x18, 0x18, 0x0C, 0x06, 0x00, 0x00, 0x00, 0x00 },
    // ASCII 97 'a'
    { 0x00, 0x00, 0x3C, 0x06, 0x3E, 0x66, 0x3B, 0x00 },
    // ASCII 98 'b'
    { 0x60, 0x60, 0x7C, 0x66, 0x66, 0x66, 0x7C, 0x00 },
    // ASCII 99 'c'
    { 0x00, 0x00, 0x3C, 0x66, 0x60, 0x66, 0x3C, 0x00 },
    // ASCII 100 'd'
    { 0x06, 0x06, 0x3E, 0x66, 0x66, 0x66, 0x3E, 0x00 },
    // ASCII 101 'e'
    { 0x00, 0x00, 0x3C, 0x66, 0x7E, 0x60, 0x3C, 0x00 },
    // ASCII 102 'f'
    { 0x0E, 0x18, 0x3C, 0x18, 0x18, 0x18, 0x18, 0x00 },
    // ASCII 103 'g'
    { 0x00, 0x00, 0x3E, 0x66, 0x66, 0x3E, 0x06, 0x7C },
    // ASCII 104 'h'
    { 0x60, 0x60, 0x7C, 0x66, 0x66, 0x66, 0x66, 0x00 },
    // ASCII 105 'i'
    { 0x18, 0x00, 0x38, 0x18, 0x18, 0x18, 0x3C, 0x00 },
    // ASCII 106 'j'
    { 0x06, 0x00, 0x06, 0x06, 0x06, 0x06, 0x66, 0x3C },
    // ASCII 107 'k'
    { 0x60, 0x60, 0x66, 0x6C, 0x78, 0x6C, 0x66, 0x00 },
    // ASCII 108 'l'
    { 0x38, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3C, 0x00 },
    // ASCII 109 'm'
    { 0x00, 0x00, 0x6C, 0x7E, 0x7E, 0x6B, 0x63, 0x00 },
    // ASCII 110 'n'
    { 0x00, 0x00, 0x5C, 0x66, 0x66, 0x66, 0x66, 0x00 },
    // ASCII 111 'o'
    { 0x00, 0x00, 0x3C, 0x66, 0x66, 0x66, 0x3C, 0x00 },
    // ASCII 112 'p'
    { 0x00, 0x00, 0x7C, 0x66, 0x66, 0x7C, 0x60, 0x60 },
    // ASCII 113 'q'
    { 0x00, 0x00, 0x3E, 0x66, 0x66, 0x3E, 0x06, 0x06 },
    // ASCII 114 'r'
    { 0x00, 0x00, 0x5E, 0x72, 0x60, 0x60, 0x60, 0x00 },
    // ASCII 115 's'
    { 0x00, 0x00, 0x3E, 0x60, 0x3C, 0x06, 0x7C, 0x00 },
    // ASCII 116 't'
    { 0x18, 0x18, 0x7E, 0x18, 0x18, 0x18, 0x0E, 0x00 },
    // ASCII 117 'u'
    { 0x00, 0x00, 0x66, 0x66, 0x66, 0x66, 0x3B, 0x00 },
    // ASCII 118 'v'
    { 0x00, 0x00, 0x66, 0x66, 0x66, 0x3C, 0x18, 0x00 },
    // ASCII 119 'w'
    { 0x00, 0x00, 0x63, 0x6B, 0x7F, 0x3E, 0x36, 0x00 },
    // ASCII 120 'x'
    { 0x00, 0x00, 0x66, 0x3C, 0x18, 0x3C, 0x66, 0x00 },
    // ASCII 121 'y'
    { 0x00, 0x00, 0x66, 0x66, 0x66, 0x3E, 0x06, 0x7C },
    // ASCII 122 'z'
    { 0x00, 0x00, 0x7E, 0x0C, 0x18, 0x30, 0x7E, 0x00 },
    // ASCII 123 '{'
    { 0x1C, 0x30, 0x30, 0xE0, 0x30, 0x30, 0x1C, 0x00 },
    // ASCII 124 '|'
    { 0x18, 0x18, 0x18, 0x00, 0x18, 0x18, 0x18, 0x00 },
    // ASCII 125 '}'
    { 0x38, 0x0C, 0x0C, 0x0E, 0x0C, 0x0C, 0x38, 0x00 },
    // ASCII 126 '~'
    { 0x00, 0x76, 0xDC, 0x00, 0x00, 0x00, 0x00, 0x00 },
    // ASCII 127: Non-printable DEL
    { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF }
};

void set_pixel(uint32_t x, uint32_t y, uint32_t color) {
    struct ultra_framebuffer* fb = &framebuffer->fb;
    uint8_t* framebuffer_address = (uint8_t*)(uintptr_t)0xfc000000;
    uint32_t pixel_offset = y * fb->pitch + (x * (fb->bpp / 8));

    switch (fb->format) {
        case ULTRA_FB_FORMAT_RGB888:
            framebuffer_address[pixel_offset] = (color >> 16) & 0xFF; // Red
            framebuffer_address[pixel_offset + 1] = (color >> 8) & 0xFF; // Green
            framebuffer_address[pixel_offset + 2] = color & 0xFF; // Blue
            break;
        case ULTRA_FB_FORMAT_BGR888:
            framebuffer_address[pixel_offset] = color & 0xFF; // Blue
            framebuffer_address[pixel_offset + 1] = (color >> 8) & 0xFF; // Green
            framebuffer_address[pixel_offset + 2] = (color >> 16) & 0xFF; // Red
            break;
        case ULTRA_FB_FORMAT_RGBX8888:
        case ULTRA_FB_FORMAT_XRGB8888:
            ((uint32_t*)framebuffer_address)[y * fb->width + x] = color;
            break;  
        default:
            // Invalid format.
            break;
    }
}


static void draw_char(uint32_t x, uint32_t y, char c, uint32_t color) { 
    if (c < 0) return;

    for (uint32_t row = 0; row < FONT_HEIGHT; row++) {
        for (uint32_t col = 0; col < FONT_WIDTH; col++) {
            if ((font8x8[(uint8_t)c][row] >> (7 - col)) & 1) {
                set_pixel(x + col, y + row, color);
            }
        }
    }
}

static uint32_t cursor_x = 0;
static uint32_t cursor_y = 0;
static uint32_t foreground_color = 0xFFFFFF;
static uint32_t background_color = 0x000000;

void set_foreground_color(uint32_t color) {
    foreground_color = color;
}
void set_background_color(uint32_t color) {
    background_color = color;
}
void set_colors(uint32_t fg_color, uint32_t bg_color) {
    foreground_color = fg_color;
    background_color = bg_color;
}

void clear_screen() {
    struct ultra_framebuffer* fb = &framebuffer->fb;

    for (uint32_t y = 0; y < fb->height; y++) {
        for (uint32_t x = 0; x < fb->width; x++) {
            set_pixel(x, y, background_color);
        }
    }
}

void scroll_screen() {
    struct ultra_framebuffer* fb = &framebuffer->fb;
    uint8_t* framebuffer_address = (uint8_t*)(uintptr_t)0xfc000000;
    
    for (uint32_t y = 0; y < fb->height - FONT_HEIGHT; y++) {
        for (uint32_t x = 0; x < fb->width; x++) {
            uint32_t src_offset = (y + FONT_HEIGHT) * fb->pitch + (x * (fb->bpp / 8));
            uint32_t dest_offset = y * fb->pitch + (x * (fb->bpp / 8));
            framebuffer_address[dest_offset] = framebuffer_address[src_offset];
            framebuffer_address[dest_offset + 1] = framebuffer_address[src_offset + 1];
            framebuffer_address[dest_offset + 2] = framebuffer_address[src_offset + 2];
        }
    }

    for (uint32_t x = 0; x < fb->width; x++) {
        set_pixel(x, fb->height - FONT_HEIGHT, background_color);
    }

    cursor_y -= FONT_HEIGHT;
}

void handle_backspace() {
    if (cursor_x >= FONT_WIDTH) {
        cursor_x -= FONT_WIDTH;
    } else if (cursor_y >= FONT_HEIGHT) {
        cursor_y -= FONT_HEIGHT;
        cursor_x = framebuffer->fb.width - FONT_WIDTH;
    }
    draw_char(cursor_x, cursor_y, 127, background_color);
}

void advance_cursor() {
    cursor_x += FONT_WIDTH;
    if (cursor_x >= framebuffer->fb.width) {
        cursor_x = 0;
        cursor_y += FONT_HEIGHT;
    }
}

void putc(char c) {
    switch (c) {
        case '\n':
            cursor_x = 0;
            cursor_y += FONT_HEIGHT;
            if (cursor_y >= framebuffer->fb.height) {
                scroll_screen();
            }
            break;
        case '\t':
            cursor_x += SCREEN_TAB_SIZE * FONT_WIDTH;
            if (cursor_x >= framebuffer->fb.width) {
                cursor_x = 0;
                cursor_y += FONT_HEIGHT;
            }
            if (cursor_y >= framebuffer->fb.height) {
                scroll_screen();
            }
            break;
        case '\x7F':
            handle_backspace();
            break;
        default:
            draw_char(cursor_x, cursor_y, c, foreground_color);
            advance_cursor();
            if (cursor_y >= framebuffer->fb.height) {
                scroll_screen();
            }
            break;
    }
}

void puts(const char* str) {
    while (*str) {
        putc(*str++);
    }
}

void cls() {
    clear_screen();
    cursor_x = 0;
    cursor_y = 0;

    struct ultra_framebuffer* fb = &framebuffer->fb;
    (void)fb;
    // somehow, this prevents UB
}

void set_cursor(uint32_t x, uint32_t y)
{
    cursor_x = x;
    cursor_y = y;
}