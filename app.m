
#include "TargetConditionals.h"

#if (TARGET_OS_MAC)

#import <Cocoa/Cocoa.h>

// defined in app.h
typedef struct app_t app_t;
extern void app_internal_osx_window_fullscreen_changed(app_t* app, bool fullscreen);
extern void app_internal_osx_add_key_event(app_t* app, int keyCode, char keyChar, bool isUp);
extern void app_internal_osx_add_mouse_move_event(app_t* app, int posx, int posy);
extern void app_internal_osx_add_mouse_press_event(app_t* app, int button, bool isUp, bool isDoubleClick);
extern void app_internal_osx_add_scroll_event(app_t* app, float scrollY);

@interface AppWindow : NSWindow <NSApplicationDelegate, NSWindowDelegate>
{
}
@property (retain) NSOpenGLView* glView;
@property app_t* app;
-(void) present;
@end

@implementation AppWindow
@synthesize glView;
@synthesize app;
bool shouldTerminate = false;

-(id)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)backingStoreType defer:(BOOL)flag
{
    if(self = [super initWithContentRect:contentRect styleMask:style backing:backingStoreType defer:flag])
    {
        [self setTitle:[[NSProcessInfo processInfo] processName]];
        
        // get a OpenGL 3.2 context
        NSOpenGLPixelFormatAttribute pixelFormatAttributes[] = {
            NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
            NSOpenGLPFAColorSize,   24,
            NSOpenGLPFAAlphaSize,   8,
            NSOpenGLPFADepthSize,   24,
            NSOpenGLPFAStencilSize, 8,
            NSOpenGLPFADoubleBuffer,
            NSOpenGLPFAAccelerated,
            NSOpenGLPFANoRecovery,
            0
        };
        
        NSOpenGLPixelFormat* format = [[NSOpenGLPixelFormat alloc] initWithAttributes:pixelFormatAttributes];

        glView = [[NSOpenGLView alloc]initWithFrame:contentRect pixelFormat:format];
        
        [glView acceptsFirstResponder];
        [[glView openGLContext] makeCurrentContext];
        GLint swapInt = 1;
        [[glView openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
        [self setContentView:glView];

        [glView prepareOpenGL];
        
        [self setDelegate:self];
        [self setAcceptsMouseMovedEvents:YES];
        [self setOpaque:YES];
    }
    
    return self;
}

-(void) present
{
    if([self isVisible])
    {
        [[glView openGLContext] flushBuffer];
    }
}

-(void) keyDown:(NSEvent *)event
{
    // empty function, but necessary to swallow the key event, so it isn't considered as unhandled.
}

-(void) applicationDidFinishLaunching:(NSNotification *)notification
{
}

-(BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

-(NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    shouldTerminate = true;
    
    // don't terminate immediately, just wait for the app to close.
    return NSTerminateCancel;
}

-(void) windowWillClose:(NSNotification *)notification
{
    shouldTerminate = true;
}

-(void) windowDidResize:(NSNotification *)notification
{
    [glView setFrame:[self contentLayoutRect]];
}

-(void) windowDidMove:(NSNotification *)notification
{
    
}

-(void) windowDidMiniaturize:(NSNotification *)notification
{
    
}

-(void) windowDidDeminiaturize:(NSNotification *)notification
{
    
}

-(void) windowDidEnterFullScreen:(NSNotification *)notification
{
    NSRect screenFrame = [[NSScreen mainScreen] frame];
    [self setFrame:screenFrame display:YES];

    app_internal_osx_window_fullscreen_changed(app, true);
}

-(void) windowDidExitFullScreen:(NSNotification *)notification
{
    app_internal_osx_window_fullscreen_changed(app, false);
}

-(void) windowDidBecomeKey:(NSNotification *)notification
{
//    printf("Window Is Key\n");
}

-(void) windowDidResignKey:(NSNotification *)notification
{
//    printf("Window Not Key\n");
}

-(void) windowDidBecomeMain:(NSNotification *)notification
{
//    printf("Window Is Main\n");
}

-(void) windowDidResignMain:(NSNotification *)notification
{
//    printf("Window Not Main\n");
}

@end

int app_internal_osx_get_screen_count()
{
    return (int)[[NSScreen screens] count];
}

void app_internal_osx_get_screen_rect(int screen_idx, int* x, int* y, int* w, int* h)
{
    NSArray* screens = [NSScreen screens];
    if(screen_idx < 0 || screen_idx >= [screens count])
        return;
    
    NSRect screenFrame = [[screens objectAtIndex:screen_idx] frame];
    if(x != NULL) *x = screenFrame.origin.x;
    if(y != NULL) *y = screenFrame.origin.y;
    if(w != NULL) *w = screenFrame.size.width;
    if(h != NULL) *h = screenFrame.size.height;
}

void app_internal_osx_get_window_position(AppWindow* app_window, int* x, int* y)
{
    NSRect windowFrame = [app_window frame];
    if(x != NULL) *x = windowFrame.origin.x;
    if(y != NULL) *y = windowFrame.origin.y;
}

void app_internal_osx_get_window_content_size(AppWindow* app_window, int* w, int* h)
{
    NSRect contentFrame = [app_window contentLayoutRect];
    if(w != NULL) *w = contentFrame.size.width;
    if(h != NULL) *h = contentFrame.size.height;
}

void app_internal_osx_set_window_position(AppWindow* app_window, int x, int y)
{
    [app_window setFrameOrigin:NSMakePoint(x,y)];
}

void app_internal_osx_set_window_content_size(AppWindow* app_window, int w, int h)
{
    [app_window setContentSize:NSMakeSize(w,h)];
}

void app_internal_osx_set_window_title(AppWindow* app_window, const char* title)
{
    [app_window setTitle:[NSString stringWithUTF8String:title]];
}

void app_internal_osx_show_window(AppWindow* app_window)
{
    [app_window makeKeyAndOrderFront:app_window];
}

void app_internal_osx_set_fullscreen(AppWindow* app_window, bool fullscreen)
{
    bool isFS = (([app_window styleMask] & NSWindowStyleMaskFullScreen) == NSWindowStyleMaskFullScreen);
    
    if(isFS == fullscreen)
        return;
    
    if(fullscreen)
    {
        NSRect screenFrame = [[NSScreen mainScreen] frame];
        [app_window setFrame:screenFrame display:YES];
        [app_window toggleFullScreen:app_window];
    }
    else
    {
        [app_window toggleFullScreen:app_window];
    }
}

void app_internal_osx_handle_events(AppWindow* app_window)
{
    @autoreleasepool
    {
        while(true)
        {
            NSEvent* event = [NSApp nextEventMatchingMask:NSEventMaskAny untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES];
            if(event == NULL)
                break;
            
            switch(event.type)
            {
                case NSEventTypeKeyDown:
                case NSEventTypeKeyUp:
                    {
                        bool isUp = event.type == NSEventTypeKeyUp;
                        app_internal_osx_add_key_event([app_window app], event.keyCode, event.characters.UTF8String[0], isUp);
                    }
                    break;
                case NSEventTypeMouseMoved:
                case NSEventTypeLeftMouseDragged:
                case NSEventTypeOtherMouseDragged:
                    {
                        NSPoint event_location = event.locationInWindow;
                        NSOpenGLView* glView = [app_window glView];
                        NSPoint local_point = [glView convertPoint:event_location fromView:nil];
                        int view_height = glView.bounds.size.height;
                        int x = (int)local_point.x;
                        int y = (int)(view_height - local_point.y - 1);
                        
                        app_internal_osx_add_mouse_move_event([app_window app], x,y);
                    }
                    break;
                case NSEventTypeLeftMouseDown:
                case NSEventTypeOtherMouseDown:
                    {
                        bool doubleClick = ((int)(event.clickCount) % 2) == 0;
                        int buttonNum = (int)event.buttonNumber;
                        
                        app_internal_osx_add_mouse_press_event([app_window app], buttonNum, false, doubleClick);
                    }
                    break;
                case NSEventTypeLeftMouseUp:
                case NSEventTypeOtherMouseUp:
                    {
                        int buttonNum = (int)event.buttonNumber;
                        app_internal_osx_add_mouse_press_event([app_window app], buttonNum, true, false);
                    }
                    break;
                case NSEventTypeScrollWheel:
                    app_internal_osx_add_scroll_event([app_window app], (float)event.deltaY);
       //             printf("Scroll Wheel %f\n", (float)event.deltaY);
                    break;
                default:
                    break;
            }

            [NSApp sendEvent:event];
        }
    }
}

void app_internal_osx_present(AppWindow* app_window)
{
    [app_window present];
}

bool app_internal_osx_should_terminate()
{
    return shouldTerminate;
}

void app_internal_osx_cancel_terminate()
{
    shouldTerminate = false;
}

AppWindow* app_internal_osx_view_init(app_t* app, int width, int height)
{
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [NSApp setPresentationOptions:NSApplicationPresentationDefault];
    
    // create the window
    AppWindow* app_window = [[AppWindow alloc] initWithContentRect:NSMakeRect(0,0,width,height)
                            styleMask:NSWindowStyleMaskClosable | NSWindowStyleMaskTitled |NSWindowStyleMaskMiniaturizable
                            backing:NSBackingStoreBuffered defer:YES];
    
    [app_window setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];
    [app_window setApp:app];
    
    // add a menubar with a quit option
    id menubar = [NSMenu new];
    id appMenuItem = [NSMenuItem new];
    [menubar addItem:appMenuItem];
    [NSApp setMainMenu:menubar];
    id appMenu = [NSMenu new];
    id appName = [[NSProcessInfo processInfo] processName];
    id quitTitle = [@"Quit " stringByAppendingString:appName];
    id quitMenuItem = [[NSMenuItem alloc] initWithTitle:quitTitle action:@selector(terminate:) keyEquivalent:@"q"];
    [appMenu addItem:quitMenuItem];
    [appMenuItem setSubmenu:appMenu];
    
    [NSApp setDelegate:app_window];
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp finishLaunching];
    
    return app_window;
}

#elif (TARGET_OS_IOS)

// one day
#error iOS not yet supported

#endif
