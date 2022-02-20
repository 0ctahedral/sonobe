//! All the functions we are going to use
pub const XCB = struct {
pub const Display = extern opaque{};
pub const xcb_connection_t = extern opaque{};
pub const xcb_keycode_t = u8;
pub const xcb_colormap_t = u32;
pub const xcb_visualid_t = u32;
pub const xcb_window_t = u32;
pub const xcb_setup_t = extern struct {
    status: u8,
    pad0: u8,
    protocol_major_version: u16,
    protocol_minor_version: u16,
    length: u16,
    release_number: u32,
    resource_id_base: u32,
    resource_id_mask: u32,
    motion_buffer_size: u32,
    vendor_len: u16,
    maximum_request_length: u16,
    roots_len: u8,
    pixmap_formats_len: u8,
    image_byte_order: u8,
    bitmap_format_bit_order: u8,
    bitmap_format_scanline_unit: u8,
    bitmap_format_scanline_pad: u8,
    min_keycode: xcb_keycode_t,
    max_keycode: xcb_keycode_t,
    pad1: [4]u8,
};
pub const xcb_screen_iterator_t = extern struct {
    data: [*]xcb_screen_t,
    rem: u32,
    index: u32,
};
pub const xcb_screen_t = extern struct {
    root: xcb_window_t,
    default_colormap: xcb_colormap_t,
    white_pixel: u32,
    black_pixel: u32,
    current_input_masks: u32,
    width_in_pixels: u16,
    height_in_pixels: u16,
    width_in_millimeters: u16,
    height_in_millimeters: u16,
    min_installed_maps: u16,
    max_installed_maps: u16,
    root_visual: xcb_visualid_t,
    backing_stores: u8,
    save_unders: u8,
    root_depth: u8,
    allowed_depths_len: u8,
};
pub const xcb_void_cookie_t = extern struct {
    sequence: u32,
};

pub const xcb_atom_t = u32;
pub const xcb_intern_atom_cookie_t = extern struct {
    sequence: c_uint,
};
pub const xcb_intern_atom_reply_t = extern struct {
    response_type: u8,
    pad0: u8,
    sequence: u16,
    length: u32,
    atom: xcb_atom_t,
};

pub const xcb_timestamp_t = u32;
pub const xcb_key_press_event_t = extern struct {
    response_type: u8,
    detail: xcb_keycode_t,
    sequence: u16,
    time: xcb_timestamp_t,
    root: xcb_window_t,
    event: xcb_window_t,
    child: xcb_window_t,
    root_x: i16,
    root_y: i16,
    event_x: i16,
    event_y: i16,
    state: u16,
    same_screen: u8,
    pad0: u8,
};
pub const xcb_client_message_data_t = extern union {
    data8: [20]u8,
    data16: [10]u16,
    data32: [5]u32,
};
pub const xcb_client_message_event_t = extern struct {
    response_type: u8,
    format: u8,
    sequence: u16,
    window: xcb_window_t,
    type: xcb_atom_t,
    data: xcb_client_message_data_t,
};
pub const xcb_generic_event_t = extern struct {
    response_type: u8,
    pad0: u8,
    sequence: u16,
    pad: [7]u32,
    full_sequence: u32,
};

pub const xcb_button_t = u8;
pub const xcb_button_press_event_t = struct {
    response_type: u8,
    detail: xcb_button_t,
    sequence: u16,
    time: xcb_timestamp_t,
    root: xcb_window_t,
    event: xcb_window_t,
    child: xcb_window_t,
    root_x: i16,
    root_y: i16,
    event_x: i16,
    event_y: i16,
    state: u16,
    same_screen: u8,
    pad0: u8,
};
pub const xcb_button_release_event_t = xcb_button_press_event_t;

pub const xcb_motion_notify_event_t = struct {
    response_type: u8,
    detail: u8,
    sequence: u16,
    time: xcb_timestamp_t,
    root: xcb_window_t,
    event: xcb_window_t,
    child: xcb_window_t,
    root_x: i16,
    root_y: i16,
    event_x: i16,
    event_y: i16,
    state: u16,
    same_screen: u8,
    pad0: u8,
};

pub const xcb_configure_notify_event_t = struct {
    response_type: u8,
    pad0:          u8,
    sequence:      u16,
    event:         xcb_window_t,
    window:        xcb_window_t,
    above_sibling: xcb_window_t, 
    x:             i16,
    y:             i16,
    width:         u16,
    height:        u16,
    border_width:  u16,
    override_redirect: u8,
    pad1:         u8,
};

pub const XCB_CW_BACK_PIXMAP = 1;
pub const XCB_CW_BACK_PIXEL = 2;
pub const XCB_CW_BORDER_PIXMAP = 4;
pub const XCB_CW_BORDER_PIXEL = 8;
pub const XCB_CW_BIT_GRAVITY = 16;
pub const XCB_CW_WIN_GRAVITY = 32;
pub const XCB_CW_BACKING_STORE = 64;
pub const XCB_CW_BACKING_PLANES = 128;
pub const XCB_CW_BACKING_PIXEL = 256;
pub const XCB_CW_OVERRIDE_REDIRECT = 512;
pub const XCB_CW_SAVE_UNDER = 1024;
pub const XCB_CW_EVENT_MASK = 2048;
pub const XCB_CW_DONT_PROPAGATE = 4096;
pub const XCB_CW_COLORMAP = 8192;
pub const XCB_CW_CURSOR = 16384;
pub const XCB_EVENT_MASK_NO_EVENT = 0;
pub const XCB_EVENT_MASK_KEY_PRESS = 1;
pub const XCB_EVENT_MASK_KEY_RELEASE = 2;
pub const XCB_EVENT_MASK_BUTTON_PRESS = 4;
pub const XCB_EVENT_MASK_BUTTON_RELEASE = 8;
pub const XCB_EVENT_MASK_ENTER_WINDOW = 16;
pub const XCB_EVENT_MASK_LEAVE_WINDOW = 32;
pub const XCB_EVENT_MASK_POINTER_MOTION = 64;
pub const XCB_EVENT_MASK_POINTER_MOTION_HINT = 128;
pub const XCB_EVENT_MASK_BUTTON_1_MOTION = 256;
pub const XCB_EVENT_MASK_BUTTON_2_MOTION = 512;
pub const XCB_EVENT_MASK_BUTTON_3_MOTION = 1024;
pub const XCB_EVENT_MASK_BUTTON_4_MOTION = 2048;
pub const XCB_EVENT_MASK_BUTTON_5_MOTION = 4096;
pub const XCB_EVENT_MASK_BUTTON_MOTION = 8192;
pub const XCB_EVENT_MASK_KEYMAP_STATE = 16384;
pub const XCB_EVENT_MASK_EXPOSURE = 32768;
pub const XCB_EVENT_MASK_VISIBILITY_CHANGE = 65536;
pub const XCB_EVENT_MASK_STRUCTURE_NOTIFY = 131072;
pub const XCB_EVENT_MASK_RESIZE_REDIRECT = 262144;
pub const XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY = 524288;
pub const XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT = 1048576;
pub const XCB_EVENT_MASK_FOCUS_CHANGE = 2097152;
pub const XCB_EVENT_MASK_PROPERTY_CHANGE = 4194304;
pub const XCB_EVENT_MASK_COLOR_MAP_CHANGE = 8388608;
pub const XCB_EVENT_MASK_OWNER_GRAB_BUTTON = 16777216;
pub const XCB_COPY_FROM_PARENT = @as(c_long, 0);
pub const XCB_WINDOW_CLASS_COPY_FROM_PARENT = 0;
pub const XCB_WINDOW_CLASS_INPUT_OUTPUT = 1;
pub const XCB_WINDOW_CLASS_INPUT_ONLY = 2;
pub const XCB_PROP_MODE_REPLACE = 0;
pub const XCB_PROP_MODE_PREPEND = 1;
pub const XCB_PROP_MODE_APPEND = 2;

pub const XCB_ATOM_WM_NAME = 39;
pub const XCB_ATOM_STRING = 31;

// events we might use TODO: add more
pub const XCB_KEY_PRESS = @as(c_int, 2);
pub const XCB_KEY_RELEASE = @as(c_int, 3);
pub const XCB_CLIENT_MESSAGE = @as(c_int, 33);
pub const XCB_BUTTON_PRESS = @as(c_int, 4);
pub const XCB_BUTTON_RELEASE = @as(c_int, 5);
pub const XCB_MOTION_NOTIFY = @as(c_int, 6);
pub const XCB_CONFIGURE_NOTIFY = @as(c_int, 22);

pub extern fn XGetXCBConnection(dpy: *Display) *xcb_connection_t;
pub extern fn XOpenDisplay(?[*]u8) ?*Display;
pub extern fn xcb_connection_has_error(c: *xcb_connection_t) c_int;
pub extern fn XAutoRepeatOff(dpy: *Display) c_int;
pub extern fn XAutoRepeatOn(dpy: *Display) c_int;
pub extern fn xcb_get_setup(c: *xcb_connection_t) *xcb_setup_t;
pub extern fn xcb_setup_roots_iterator(R: *const xcb_setup_t) xcb_screen_iterator_t;
pub extern fn xcb_generate_id(c: *xcb_connection_t) u32;
pub extern fn xcb_create_window(c: *xcb_connection_t, depth: u8, wid: xcb_window_t, parent: xcb_window_t, x: i16, y: i16, width: u16, height: u16, border_width: u16, _class: u16, visual: xcb_visualid_t, value_mask: u32, value_list: ?*const anyopaque) xcb_void_cookie_t;
pub extern fn xcb_intern_atom_reply(c: *xcb_connection_t, cookie: xcb_intern_atom_cookie_t, e: ?*anyopaque) *xcb_intern_atom_reply_t;
pub extern fn xcb_intern_atom(c: *xcb_connection_t, only_if_exists: u8, name_len: u16, name: [*]const u8) xcb_intern_atom_cookie_t;
pub extern fn xcb_change_property(c: *xcb_connection_t, mode: u8, window: xcb_window_t, property: xcb_atom_t, type: xcb_atom_t, format: u8, data_len: u32, data: ?*const anyopaque) xcb_void_cookie_t;
pub extern fn xcb_map_window(c: *xcb_connection_t, window: xcb_window_t) xcb_void_cookie_t;
pub extern fn xcb_flush(c: *xcb_connection_t) c_int;
pub extern fn xcb_destroy_window(c: *xcb_connection_t, w: xcb_window_t) c_int; 
pub extern fn xcb_poll_for_event(c: *xcb_connection_t) ?*xcb_generic_event_t;

pub extern fn XkbKeycodeToKeysym(*Display, u8, u32, u32) u32;
pub const ShiftMask: u8 = 1<<0;


pub const XK_space: u32 = 0x0020;
pub const XK_BackSpace: u32 = 0xff08;
pub const XK_Tab: u32 = 0xff09;
pub const XK_Linefeed: u32 = 0xff0a;
pub const XK_Clear: u32 = 0xff0b;
pub const XK_Return: u32 = 0xff0d;
pub const XK_Pause: u32 = 0xff13;
pub const XK_Scroll_Lock: u32 = 0xff14;
pub const XK_Sys_Req: u32 = 0xff15;
pub const XK_Escape: u32 = 0xff1b;
pub const XK_Delete: u32 = 0xffff;


pub const XK_F1: u32 = 0xffbe;
pub const XK_F2: u32 = 0xffbf;
pub const XK_F3: u32 = 0xffc0;
pub const XK_F4: u32 = 0xffc1;
pub const XK_F5: u32 = 0xffc2;
pub const XK_F6: u32 = 0xffc3;
pub const XK_F7: u32 = 0xffc4;
pub const XK_F8: u32 = 0xffc5;
pub const XK_F9: u32 = 0xffc6;
pub const XK_F10: u32 = 0xffc7;
pub const XK_F11: u32 = 0xffc8;
pub const XK_L1: u32 = 0xffc8;
pub const XK_F12: u32 = 0xffc9;
pub const XK_L2: u32 = 0xffc9;
pub const XK_F13: u32 = 0xffca;
pub const XK_L3: u32 = 0xffca;
pub const XK_F14: u32 = 0xffcb;
pub const XK_L4: u32 = 0xffcb;
pub const XK_F15: u32 = 0xffcc;
pub const XK_L5: u32 = 0xffcc;
pub const XK_F16: u32 = 0xffcd;
pub const XK_L6: u32 = 0xffcd;
pub const XK_F17: u32 = 0xffce;
pub const XK_L7: u32 = 0xffce;
pub const XK_F18: u32 = 0xffcf;
pub const XK_L8: u32 = 0xffcf;
pub const XK_F19: u32 = 0xffd0;
pub const XK_L9: u32 = 0xffd0;
pub const XK_F20: u32 = 0xffd1;
pub const XK_L10: u32 = 0xffd1;
pub const XK_F21: u32 = 0xffd2;
pub const XK_R1: u32 = 0xffd2;
pub const XK_F22: u32 = 0xffd3;
pub const XK_R2: u32 = 0xffd3;
pub const XK_F23: u32 = 0xffd4;
pub const XK_R3: u32 = 0xffd4;
pub const XK_F24: u32 = 0xffd5;
pub const XK_R4: u32 = 0xffd5;
pub const XK_F25: u32 = 0xffd6;
pub const XK_R5: u32 = 0xffd6;
pub const XK_F26: u32 = 0xffd7;
pub const XK_R6: u32 = 0xffd7;
pub const XK_F27: u32 = 0xffd8;
pub const XK_R7: u32 = 0xffd8;
pub const XK_F28: u32 = 0xffd9;
pub const XK_R8: u32 = 0xffd9;
pub const XK_F29: u32 = 0xffda;
pub const XK_R9: u32 = 0xffda;
pub const XK_F30: u32 = 0xffdb;
pub const XK_R10: u32 = 0xffdb;
pub const XK_F31: u32 = 0xffdc;
pub const XK_R11: u32 = 0xffdc;
pub const XK_F32: u32 = 0xffdd;
pub const XK_R12: u32 = 0xffdd;
pub const XK_F33: u32 = 0xffde;
pub const XK_R13: u32 = 0xffde;
pub const XK_F34: u32 = 0xffdf;
pub const XK_R14: u32 = 0xffdf;
pub const XK_F35: u32 = 0xffe0;
pub const XK_R15: u32 = 0xffe0;

pub const XK_Shift_L: u32 = 0xffe1;  // Left shift */
pub const XK_Shift_R: u32 = 0xffe2;  // Right shift */
pub const XK_Control_L: u32 = 0xffe3;  // Left control */
pub const XK_Control_R: u32 = 0xffe4;  // Right control */
pub const XK_Caps_Lock: u32 = 0xffe5;  // Caps lock */
pub const XK_Shift_Lock: u32 = 0xffe6;  // Shift lock */

pub const XK_Meta_L: u32 = 0xffe7;  // Left meta */
pub const XK_Meta_R: u32 = 0xffe8;  // Right meta */
pub const XK_Alt_L: u32 = 0xffe9;  // Left alt */
pub const XK_Alt_R: u32 = 0xffea;  // Right alt */
pub const XK_Super_L: u32 = 0xffeb;  // Left super */
pub const XK_Super_R: u32 = 0xffec;  // Right super */
pub const XK_Hyper_L: u32 = 0xffed;  // Left hyper */
pub const XK_Hyper_R: u32 = 0xffee;  // Right hyper */

pub const XK_Select: u32 = 0xff60;  // Select, mark */
pub const XK_Print: u32 = 0xff61;
pub const XK_Execute: u32 = 0xff62;  // Execute, run, do */
pub const XK_Insert: u32 = 0xff63;  // Insert, insert here */
pub const XK_Undo: u32 = 0xff65;
pub const XK_Redo: u32 = 0xff66;  // Redo, again */
pub const XK_Menu: u32 = 0xff67;
pub const XK_Find: u32 = 0xff68;  // Find, search */
pub const XK_Cancel: u32 = 0xff69;  // Cancel, stop, abort, exit */
pub const XK_Help: u32 = 0xff6a;  // Help */
pub const XK_Break: u32 = 0xff6b;
pub const XK_Mode_switch: u32 = 0xff7e;  // Character set switch */
pub const XK_script_switch: u32 = 0xff7e;  // Alias for mode_switch */
pub const XK_Num_Lock: u32 = 0xff7f;

pub const XK_Home: u32 = 0xff50;
pub const XK_Left: u32 = 0xff51;  // Move left, left arrow */
pub const XK_Up: u32 = 0xff52;  // Move up, up arrow */
pub const XK_Right: u32 = 0xff53;  // Move right, right arrow */
pub const XK_Down: u32 = 0xff54;  // Move down, down arrow */
pub const XK_Prior: u32 = 0xff55;  // Prior, previous */
pub const XK_Page_Up: u32 = 0xff55;
pub const XK_Next: u32 = 0xff56;  // Next */
pub const XK_Page_Down: u32 = 0xff56;
pub const XK_End: u32 = 0xff57;  // EOL */
pub const XK_Begin: u32 = 0xff58;  // BOL */

pub const XK_multiply: u32 = 0x00d7;  
pub const XK_KP_Equal: u32 = 0xffbd;
pub const XK_KP_Add: u32 = 0xffab;
pub const XK_KP_Separator: u32 = 0xffac;  // Separator, often comma */
pub const XK_KP_Subtract: u32 = 0xffad;
pub const XK_KP_Decimal: u32 = 0xffae;
pub const XK_KP_Divide: u32 = 0xffaf;

pub const XK_KP_0: u32 = 0xffb0;
pub const XK_KP_1: u32 = 0xffb1;
pub const XK_KP_2: u32 = 0xffb2;
pub const XK_KP_3: u32 = 0xffb3;
pub const XK_KP_4: u32 = 0xffb4;
pub const XK_KP_5: u32 = 0xffb5;
pub const XK_KP_6: u32 = 0xffb6;
pub const XK_KP_7: u32 = 0xffb7;
pub const XK_KP_8: u32 = 0xffb8;
pub const XK_KP_9: u32 = 0xffb9;

pub const XK_exclam: u32 = 0x0021;  // U+0021 EXCLAMATION MARK */
pub const XK_quotedbl: u32 = 0x0022;  // U+0022 QUOTATION MARK */
pub const XK_numbersign: u32 = 0x0023;  // U+0023 NUMBER SIGN */
pub const XK_dollar: u32 = 0x0024;  // U+0024 DOLLAR SIGN */
pub const XK_percent: u32 = 0x0025;  // U+0025 PERCENT SIGN */
pub const XK_ampersand: u32 = 0x0026;  // U+0026 AMPERSAND */
pub const XK_apostrophe: u32 = 0x0027;  // U+0027 APOSTROPHE */
pub const XK_quoteright: u32 = 0x0027;  // deprecated */
pub const XK_parenleft: u32 = 0x0028;  // U+0028 LEFT PARENTHESIS */
pub const XK_parenright: u32 = 0x0029;  // U+0029 RIGHT PARENTHESIS */
pub const XK_asterisk: u32 = 0x002a;  // U+002A ASTERISK */
pub const XK_plus: u32 = 0x002b;  // U+002B PLUS SIGN */
pub const XK_comma: u32 = 0x002c;  // U+002C COMMA */
pub const XK_minus: u32 = 0x002d;  // U+002D HYPHEN-MINUS */
pub const XK_period: u32 = 0x002e;  // U+002E FULL STOP */
pub const XK_slash: u32 = 0x002f;  // U+002F SOLIDUS */
pub const XK_0: u32 = 0x0030;  // U+0030 DIGIT ZERO */
pub const XK_1: u32 = 0x0031;  // U+0031 DIGIT ONE */
pub const XK_2: u32 = 0x32;  // U+0032 DIGIT TWO */
pub const XK_3: u32 = 0x0033;  // U+0033 DIGIT THREE */
pub const XK_4: u32 = 0x0034;  // U+0034 DIGIT FOUR */
pub const XK_5: u32 = 0x0035;  // U+0035 DIGIT FIVE */
pub const XK_6: u32 = 0x0036;  // U+0036 DIGIT SIX */
pub const XK_7: u32 = 0x0037;  // U+0037 DIGIT SEVEN */
pub const XK_8: u32 = 0x0038;  // U+0038 DIGIT EIGHT */
pub const XK_9: u32 = 0x0039;  // U+0039 DIGIT NINE */
pub const XK_colon: u32 = 0x003a;  // U+003A COLON */
pub const XK_semicolon: u32 = 0x003b;  // U+003B SEMICOLON */
pub const XK_less: u32 = 0x003c;  // U+003C LESS-THAN SIGN */
pub const XK_equal: u32 = 0x003d;  // U+003D EQUALS SIGN */
pub const XK_greater: u32 = 0x003e;  // U+003E GREATER-THAN SIGN */
pub const XK_question: u32 = 0x003f;  // U+003F QUESTION MARK */
pub const XK_at: u32 = 0x0040;  // U+0040 COMMERCIAL AT */
pub const XK_A: u32 = 0x0041;  // U+0041 LATIN CAPITAL LETTER A */
pub const XK_B: u32 = 0x0042;  // U+0042 LATIN CAPITAL LETTER B */
pub const XK_C: u32 = 0x0043;  // U+0043 LATIN CAPITAL LETTER C */
pub const XK_D: u32 = 0x0044;  // U+0044 LATIN CAPITAL LETTER D */
pub const XK_E: u32 = 0x0045;  // U+0045 LATIN CAPITAL LETTER E */
pub const XK_F: u32 = 0x0046;  // U+0046 LATIN CAPITAL LETTER F */
pub const XK_G: u32 = 0x0047;  // U+0047 LATIN CAPITAL LETTER G */
pub const XK_H: u32 = 0x0048;  // U+0048 LATIN CAPITAL LETTER H */
pub const XK_I: u32 = 0x0049;  // U+0049 LATIN CAPITAL LETTER I */
pub const XK_J: u32 = 0x004a;  // U+004A LATIN CAPITAL LETTER J */
pub const XK_K: u32 = 0x004b;  // U+004B LATIN CAPITAL LETTER K */
pub const XK_L: u32 = 0x004c;  // U+004C LATIN CAPITAL LETTER L */
pub const XK_M: u32 = 0x004d;  // U+004D LATIN CAPITAL LETTER M */
pub const XK_N: u32 = 0x004e;  // U+004E LATIN CAPITAL LETTER N */
pub const XK_O: u32 = 0x004f;  // U+004F LATIN CAPITAL LETTER O */
pub const XK_P: u32 = 0x0050;  // U+0050 LATIN CAPITAL LETTER P */
pub const XK_Q: u32 = 0x0051;  // U+0051 LATIN CAPITAL LETTER Q */
pub const XK_R: u32 = 0x0052;  // U+0052 LATIN CAPITAL LETTER R */
pub const XK_S: u32 = 0x0053;  // U+0053 LATIN CAPITAL LETTER S */
pub const XK_T: u32 = 0x0054;  // U+0054 LATIN CAPITAL LETTER T */
pub const XK_U: u32 = 0x0055;  // U+0055 LATIN CAPITAL LETTER U */
pub const XK_V: u32 = 0x0056;  // U+0056 LATIN CAPITAL LETTER V */
pub const XK_W: u32 = 0x0057;  // U+0057 LATIN CAPITAL LETTER W */
pub const XK_X: u32 = 0x0058;  // U+0058 LATIN CAPITAL LETTER X */
pub const XK_Y: u32 = 0x0059;  // U+0059 LATIN CAPITAL LETTER Y */
pub const XK_Z: u32 = 0x005a;  // U+005A LATIN CAPITAL LETTER Z */
pub const XK_bracketleft: u32 = 0x005b;  // U+005B LEFT SQUARE BRACKET */
pub const XK_backslash: u32 = 0x005c;  // U+005C REVERSE SOLIDUS */
pub const XK_braceleft: u32 = 0x007b;  // U+007B LEFT CURLY BRACKET */
pub const XK_bar: u32 = 0x007c;  // U+007C VERTICAL LINE */
pub const XK_braceright: u32 = 0x007d;  // U+008D RIGHT CURLY BRACKET */
pub const XK_bracketright: u32 = 0x005d;  // U+005D RIGHT SQUARE BRACKET */
pub const XK_asciicircum: u32 = 0x005e;  // U+005E CIRCUMFLEX ACCENT */
pub const XK_underscore: u32 = 0x005f;  // U+005F LOW LINE */
pub const XK_grave: u32 = 0x0060;  // U+0060 GRAVE ACCENT */
pub const XK_quoteleft: u32 = 0x0060;  // deprecated */
pub const XK_a: u32 = 0x0061;  // U+0061 LATIN SMALL LETTER A */
pub const XK_b: u32 = 0x0062;  // U+0062 LATIN SMALL LETTER B */
pub const XK_c: u32 = 0x0063;  // U+0063 LATIN SMALL LETTER C */
pub const XK_d: u32 = 0x0064;  // U+0064 LATIN SMALL LETTER D */
pub const XK_e: u32 = 0x0065;  // U+0065 LATIN SMALL LETTER E */
pub const XK_f: u32 = 0x0066;  // U+0066 LATIN SMALL LETTER F */
pub const XK_g: u32 = 0x0067;  // U+0067 LATIN SMALL LETTER G */
pub const XK_h: u32 = 0x0068;  // U+0068 LATIN SMALL LETTER H */
pub const XK_i: u32 = 0x0069;  // U+0069 LATIN SMALL LETTER I */
pub const XK_j: u32 = 0x006a;  // U+006A LATIN SMALL LETTER J */
pub const XK_k: u32 = 0x006b;  // U+006B LATIN SMALL LETTER K */
pub const XK_l: u32 = 0x006c;  // U+006C LATIN SMALL LETTER L */
pub const XK_m: u32 = 0x006d;  // U+006D LATIN SMALL LETTER M */
pub const XK_n: u32 = 0x006e;  // U+006E LATIN SMALL LETTER N */
pub const XK_o: u32 = 0x006f;  // U+006F LATIN SMALL LETTER O */
pub const XK_p: u32 = 0x0070;  // U+0070 LATIN SMALL LETTER P */
pub const XK_q: u32 = 0x0071;  // U+0071 LATIN SMALL LETTER Q */
pub const XK_r: u32 = 0x0072;  // U+0072 LATIN SMALL LETTER R */
pub const XK_s: u32 = 0x0073;  // U+0073 LATIN SMALL LETTER S */
pub const XK_t: u32 = 0x0074;  // U+0074 LATIN SMALL LETTER T */
pub const XK_u: u32 = 0x0075;  // U+0075 LATIN SMALL LETTER U */
pub const XK_v: u32 = 0x0076;  // U+0076 LATIN SMALL LETTER V */
pub const XK_w: u32 = 0x0077;  // U+0077 LATIN SMALL LETTER W */
pub const XK_x: u32 = 0x0078;  // U+0078 LATIN SMALL LETTER X */
pub const XK_y: u32 = 0x0079;  // U+0079 LATIN SMALL LETTER Y */
pub const XK_z: u32 = 0x007a;  // U+007A LATIN SMALL LETTER Z */
pub const XK_asciitilde: u32 = 0x007e;
pub const XK_caret: u32 = 0x0afc;
};
