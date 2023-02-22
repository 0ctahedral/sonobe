#include <mach/mach_time.h>
#include <crt_externs.h>

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

// For surface creation
#define VK_USE_PLATFORM_METAL_EXT
//#include <vulkan/vulkan.h>


@class ApplicationDelegate;
@class WindowDelegate;
@class ContentView;

typedef struct platform_state {
    ApplicationDelegate* app_delegate;
    WindowDelegate* wnd_delegate;
} platform_state;

static platform_state* state_ptr;

void mouse_move(int16_t, int16_t);


bool startup(platform_state* state) {

    @autoreleasepool {

    [NSApplication sharedApplication];

    // App delegate creation
    state_ptr = state;
    state_ptr->app_delegate = [[ApplicationDelegate alloc] init];
    if (!state_ptr->app_delegate) {
        printf("Failed to create application delegate");
        return false;
    }
    [NSApp setDelegate:state_ptr->app_delegate];

    // Window delegate creation
    state_ptr->wnd_delegate = [[WindowDelegate alloc] initWithState:state_ptr];
    if (!state_ptr->wnd_delegate) {
        printf("Failed to create window delegate");
        return false;
    }


    if (![[NSRunningApplication currentApplication] isFinishedLaunching])
        [NSApp run];

    // Making the app a proper UI app since we're unbundled
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    // Putting window in front on launch
    [NSApp activateIgnoringOtherApps:YES];

    return true;

    } // autoreleasepool
}

struct win_data {
    NSWindow* window;
    ContentView* view;
    CAMetalLayer* layer;
};


struct win_data* win_ptr_to_data(NSWindow* window);
void resize_window(NSWindow*, uint16_t, uint16_t);

bool create_window(char* title, int w, int h, struct win_data* data) {

    @autoreleasepool {
    // Window creation
    data->window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, w, h)
        styleMask:NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered
        defer:NO];
    if (!data->window) {
        printf("Failed to create window");
        return false;
    }

    // Layer creation
    data->layer = [CAMetalLayer layer];
    if (!data->layer) {
        printf("Failed to create layer for view");
    }

    // View creation
    data->view = [[ContentView alloc] initWithWindow:data->window];
    [data->view setLayer:data->layer];
    [data->view setWantsLayer:YES];

    // Setting window properties
    [data->window setLevel:NSNormalWindowLevel];
    [data->window setContentView:data->view];
    [data->window makeFirstResponder:data->view];
    [data->window setTitle:@(title)];
    [data->window setDelegate:state_ptr->wnd_delegate];
    [data->window setAcceptsMouseMovedEvents:YES];
    [data->window setRestorable:NO];
    [data->window makeKeyAndOrderFront:nil];

    [data->window setStyleMask:
        NSWindowStyleMaskTitled
        |NSWindowStyleMaskResizable
        |NSWindowStyleMaskFullSizeContentView
        |NSWindowStyleMaskClosable
        |NSWindowStyleMaskMiniaturizable
    ];
    data->window.titlebarAppearsTransparent = true;
    // data->window.backgroundColor = [NSColor colorWithCalibratedRed:0.0 green:1.0 blue:0.0 alpha:0.5f];
    }

    return true;
}

void shutdown(void* platform_state) {
    if (state_ptr) {
        printf("state ptr exists\n");
        @autoreleasepool {


        [state_ptr->wnd_delegate release];
        //[state_ptr->view release];
        [state_ptr->app_delegate release];

        [NSApp setDelegate:nil];
        //[state_ptr->window setDelegate:nil];


        state_ptr->app_delegate = nil;
        //state_ptr->view = nil;
        //state_ptr->window = nil;

        //[state_ptr->window close];
        //[state_ptr->window orderOut:nil];

        } // autoreleasepool
    }
    state_ptr = 0;
}

bool pump_messages(platform_state *plat_state) {
    if (state_ptr) {
        @autoreleasepool {

        NSEvent* event;

        event = [NSApp 
            nextEventMatchingMask:NSEventMaskAny
            untilDate:[NSDate distantPast]
            inMode:NSDefaultRunLoopMode
            dequeue:YES];

        if (!event)
            return false;

        [NSApp sendEvent:event];

        return true;
        } // autoreleasepool

    }
    return false;
}


//bool platform_create_vulkan_surface(vulkan_context *context) {
//    if (!state_ptr) {
//        return false;
//    }
//
//    VkMetalSurfaceCreateInfoEXT create_info = {VK_STRUCTURE_TYPE_METAL_SURFACE_CREATE_INFO_EXT};
//    create_info.pLayer = state_ptr->layer;
//
//    VkResult result = vkCreateMetalSurfaceEXT(
//        context->instance, 
//        &create_info,
//        context->allocator,
//        &state_ptr->surface);
//    if (result != VK_SUCCESS) {
//        KFATAL("Vulkan surface creation failed.");
//        return false;
//    }
//
//    context->surface = state_ptr->surface;
//    return true;
//}

@interface WindowDelegate : NSObject <NSWindowDelegate> {
    platform_state* state;
}

- (instancetype)initWithState:(platform_state*)init_state;

@end // WindowDelegate

@implementation WindowDelegate

- (instancetype)initWithState:(platform_state*)init_state {
    self = [super init];

    if (self != nil) {
        state = init_state;
    }
    
    return self;
}

void close_window(NSWindow*);

void get_window_size(struct win_data* wd, uint16_t* w, uint16_t* h) {
    if (wd) {
      const NSRect contentRect = [wd->view frame];
      const NSRect fbRect = [wd->view convertRectToBacking:contentRect];
      *w = (uint16_t) fbRect.size.width;
      *h = (uint16_t) fbRect.size.height;
   }
}

void set_window_title(struct win_data* wd, char* title) {
    [wd->window setTitle:@(title)];
}

- (BOOL)windowShouldClose:(NSWindow*)sender {
    close_window(sender);
    return YES;
}

- (void)windowDidResize:(NSNotification *)notification {
    struct win_data* wd = win_ptr_to_data(notification.object);
    if (wd) {
      const NSRect contentRect = [wd->view frame];
      const NSRect fbRect = [wd->view convertRectToBacking:contentRect];
      resize_window(notification.object, (uint16_t) fbRect.size.width, (uint16_t)fbRect.size.height);
    }
}

- (void)windowDidMiniaturize:(NSNotification *)notification {
    /*
    event_context context;
    context.data.u16[0] = 0;
    context.data.u16[1] = 0;
    event_fire(EVENT_CODE_RESIZED, 0, context);

    [state_ptr->window miniaturize:nil];
    */
}

- (void)windowDidDeminiaturize:(NSNotification *)notification {
    /*
    event_context context;
    const NSRect contentRect = [state_ptr->view frame];
    const NSRect framebufferRect = [state_ptr->view convertRectToBacking:contentRect];
    context.data.u16[0] = (u16)framebufferRect.size.width;
    context.data.u16[1] = (u16)framebufferRect.size.height;
    event_fire(EVENT_CODE_RESIZED, 0, context);

    [state_ptr->window deminiaturize:nil];
    */
}

@end // WindowDelegate


@interface ApplicationDelegate : NSObject <NSApplicationDelegate> {}

@end // ApplicationDelegate

@implementation ApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // Posting an empty event at start
    @autoreleasepool {

    NSEvent* event = [NSEvent otherEventWithType:NSEventTypeApplicationDefined
                                        location:NSMakePoint(0, 0)
                                   modifierFlags:0
                                       timestamp:0
                                    windowNumber:0
                                         context:nil
                                         subtype:0
                                           data1:0
                                           data2:0];
    [NSApp postEvent:event atStart:YES];

    } // autoreleasepool

    [NSApp stop:nil];
}

@end // ApplicationDelegate

@interface ContentView : NSView <NSTextInputClient> {
    NSWindow* window;
    NSTrackingArea* trackingArea;
    NSMutableAttributedString* markedText;
}

- (instancetype)initWithWindow:(NSWindow*)initWindow;

@end // ContentView

@implementation ContentView

- (instancetype)initWithWindow:(NSWindow*)initWindow {
    self = [super init];
    if (self != nil) {
        window = initWindow;
    }

    return self;
}

- (BOOL)canBecomeKeyView {
    return YES;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)wantsUpdateLayer {
    return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    return YES;
}

- (void)mouseMoved:(NSEvent *)event {
    const NSPoint pos = [event locationInWindow];
    mouse_move((int16_t)pos.x, (int16_t)pos.y);
}

- (void)mouseDown:(NSEvent *)event {
    const NSPoint pos = [event locationInWindow];
    mouse_left((int16_t)pos.x, (int16_t)pos.y, true);
}

- (void)mouseUp:(NSEvent *)event {
    const NSPoint pos = [event locationInWindow];
    mouse_left((int16_t)pos.x, (int16_t)pos.y, false);
}

- (void)rightMouseDown:(NSEvent *)event {
    const NSPoint pos = [event locationInWindow];
    mouse_right((int16_t)pos.x, (int16_t)pos.y, true);
}

- (void)rightMouseUp:(NSEvent *)event {
 //   input_process_button(BUTTON_RIGHT, false);
    const NSPoint pos = [event locationInWindow];
    mouse_right((int16_t)pos.x, (int16_t)pos.y, false);
}

- (void)otherMouseDown:(NSEvent *)event {
    const NSPoint pos = [event locationInWindow];
    mouse_middle((int16_t)pos.x, (int16_t)pos.y, true);
}

- (void)otherMouseUp:(NSEvent *)event {
    // Interpreted as middle click
    const NSPoint pos = [event locationInWindow];
    mouse_middle((int16_t)pos.x, (int16_t)pos.y, false);
}

- (void)scrollWheel:(NSEvent *)event {
    //input_process_mouse_wheel((i8)[event scrollingDeltaY]);
}

- (void)mouseDragged:(NSEvent *)event {
  // Equivalent to moving the mouse for now
  [self mouseMoved:event];
}

- (void)rightMouseDragged:(NSEvent *)event  {
    // Equivalent to moving the mouse for now
    [self mouseMoved:event];
}

- (void)otherMouseDragged:(NSEvent *)event {
    // Equivalent to moving the mouse for now
    [self mouseMoved:event];
}

- (void) flagsChanged:(NSEvent *) event {
    uint32_t flags = [event modifierFlags];
    modifier_keys(
        [event keyCode],
        flags,
        flags & NSEventModifierFlagShift,
        flags & NSEventModifierFlagControl,
        flags & NSEventModifierFlagOption,
        flags & NSEventModifierFlagCommand
    );
}

- (void)keyDown:(NSEvent *)event {
    key_down((uint32_t)[event keyCode]);
    // [self interpretKeyEvents:@[event]];
}

- (void)keyUp:(NSEvent *)event {
    key_up((uint32_t)[event keyCode]);
}

- (void)insertText:(id)string replacementRange:(NSRange)replacementRange {}

- (void)setMarkedText:(id)string selectedRange:(NSRange)selectedRange replacementRange:(NSRange)replacementRange {}

- (void)unmarkText {}

// Defines a constant for empty ranges in NSTextInputClient
static const NSRange kEmptyRange = { NSNotFound, 0 };

- (NSRange)selectedRange {return kEmptyRange;}

- (NSRange)markedRange {return kEmptyRange;}

- (BOOL)hasMarkedText {return false;}

- (nullable NSAttributedString *)attributedSubstringForProposedRange:(NSRange)range actualRange:(nullable NSRangePointer)actualRange {return nil;}

- (NSArray<NSAttributedStringKey> *)validAttributesForMarkedText {return [NSArray array];}

- (NSRect)firstRectForCharacterRange:(NSRange)range actualRange:(nullable NSRangePointer)actualRange {return NSMakeRect(0, 0, 0, 0);}

- (NSUInteger)characterIndexForPoint:(NSPoint)point {return 0;}

@end // ContentView

/*

    */
