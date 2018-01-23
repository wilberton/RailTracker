#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>

#define MOD_PLAYER_IMPLEMENTATION
#include "modplayer.h"

#define APP_IMPLEMENTATION
#include "app.h"

#define XUI_GFX_IMPLEMENTATION
#include "xui_gfx.h"

#define XUI_IMPLEMENTATION
#include "xui.h"

int AppWidth = 480;
int AppHeight = 320;

void draw_ui(xui_gfx* gfx, mp_mod_player* modplayer)
{
	xui_clear(gfx, 0xff806040);

	char line_str[64];
	line_str[0] = '\0';

	int line_height = 12;
	xui_draw_rect(gfx, 4, 110 + 5*line_height, AppWidth-8, line_height, 0xffc0c0c0);

	if(xui_label_button(XID, "PLAY", 100, 18))
		modplayer_play_song(modplayer);
	if(xui_label_button(XID, "STOP", 200, 18))
		modplayer_stop(modplayer);

	mp_pattern pattern = modplayer->mod->patterns[modplayer->mod->pattern_table[modplayer->pattern_idx]];
	int active_line = modplayer->line_idx;
	for(int i=active_line - 10; i <= active_line + 10; ++i)
	{
		if(i < 0 || i >= 64)
			continue;
		
		mp_line line = pattern.lines[i];

		int text_y =  110 + 5*line_height + 2 + ((i - active_line) * line_height);
		int text_col = i == active_line ? 0xff000000 : 0xffffffff;

		sprintf(line_str, "%02d", i);
		xui_draw_string(gfx, 10, text_y, text_col, line_str);

		for(int c=0; c<4; ++c)
		{
			mp_channel_note note = line.channels[c];
			if(note.period != 0)
				sprintf(line_str, "%03d ", note.period);
			else
				sprintf(line_str, "... ");
			if(note.sample != 0)
				sprintf(line_str + 4, "%02X ", note.sample);
			else
				sprintf(line_str + 4, ".. ");
			if(note.effect_type != 0 || note.effect_param != 0)
				sprintf(line_str + 7, "%03X", (note.effect_type << 8) | note.effect_param);
			else
				sprintf(line_str + 7, "...");
			
		//	sprintf(line_str, "%03d %02X %03X", note.period, note.sample, (note.effect_type << 8) | note.effect_param);			
			xui_draw_string(gfx, 40 + 110 * c, text_y, text_col, line_str);
		}
	}
}

void handle_events(app_t* app)
{
	app_input_t input = app_input(app);
	for(int i=0; i<input.count; ++i)
	{
//		printf("Input %d\n", input.events[i].type);
		app_input_event_t event = input.events[i];
		if(event.type == APP_INPUT_MOUSE_MOVE)
		{
			int xpos = event.data.mouse_pos.x;
			int ypos = event.data.mouse_pos.y;
			app_coordinates_window_to_bitmap(app, AppWidth, AppHeight, &xpos, &ypos);

			xui->mouse_x = xpos;
			xui->mouse_y = ypos;
		}
		else if(event.type == APP_INPUT_KEY_DOWN)
		{
			if(event.data.key == APP_KEY_LBUTTON)
			{
				xui->mouse_buttons_state |= MOUSE_LEFT;
				xui->mouse_buttons_down_this_frame |= MOUSE_LEFT;
			}
            else if(event.data.key == APP_KEY_SPACE)
            {
                // todo: toggle edit state
            }
		}
		else if(event.type == APP_INPUT_KEY_UP)
		{
			if(event.data.key == APP_KEY_LBUTTON)
			{
				xui->mouse_buttons_state &= ~MOUSE_LEFT;
				xui->mouse_buttons_up_this_frame |= MOUSE_LEFT;
			}
		}
	}
}

int app_proc( app_t* app, void* user_data )
{
	app_screenmode( app, APP_SCREENMODE_WINDOW );
	app_window_size( app, AppWidth, AppHeight );
	app_interpolation(app, APP_INTERPOLATION_NONE);

	xui_gfx gfx;
	xui_init_gfx(&gfx, AppWidth, AppHeight);
	xui_init(&gfx);

	int buffer_size_in_frames = 6000;
	int buffer_bucket_size = 1500;
	int channel_count = 2;
	short* buffer = (short*)malloc(sizeof(short) * channel_count * buffer_size_in_frames);
	memset(buffer, 0x00, sizeof(short) * channel_count * buffer_size_in_frames);

	mp_mod_player* modplayer = (mp_mod_player*)user_data;
	modplayer_reset_song_to_beginning(modplayer);

	// set some params
	modplayer_set_stereo(modplayer, true);
	modplayer_set_sample_rate(modplayer, 44100);
	modplayer_set_stereo_width(modplayer, 0.5f);
	// start song
	modplayer_reset_song_to_beginning(modplayer);

	// start sound playing
	app_sound_buffer_size(app, buffer_size_in_frames);
//	modplayer_decode_frames(modplayer, buffer_size_in_frames, buffer);
	app_sound_write(app, 0, buffer_size_in_frames, buffer);

	APP_U64 previous_count = app_time_count(app);
	char fps_str[64];

	int prev_bucket_idx = 0;

	// keep running until the user closes the window
	while( app_yield( app ) != APP_STATE_EXIT_REQUESTED )
	{
		APP_U64 current_count = app_time_count( app );
		APP_U64 delta_count = current_count - previous_count;
		double delta_time = ( (double) delta_count ) / ( (double) app_time_freq( app ) );
		previous_count = current_count;

		int buffer_position = app_sound_position(app);
		int bucket_idx = buffer_position / buffer_bucket_size;
		if(bucket_idx != prev_bucket_idx)
		{
			int num_frames = buffer_bucket_size;
			modplayer_decode_frames(modplayer, num_frames, buffer);
			app_sound_write(app, prev_bucket_idx * buffer_bucket_size, num_frames, buffer);
			prev_bucket_idx = bucket_idx;
		}

		xui_begin_frame();
		handle_events(app);

		draw_ui(&gfx, modplayer);

		sprintf(fps_str, "%02.2fms", 1000.0f * delta_time);
		xui_draw_string(&gfx, 20, 20, 0xffffffff, fps_str);

		// display the canvas
		app_present( app, gfx.pixels, gfx.width, gfx.height, 0xffffff, 0x000000 );
	}

	free(buffer);

	xui_destroy_gfx(&gfx);
	xui_shutdown();
	return 0;
}

int main(int argc, char *argv[])
{
	(void) argc; (void) argv;

    char* modfile;
	// tmp - require a mod file on the command line
	if(argc != 2)
	{
//		printf("Usage: WolfTracker <modfile.mod>\n");
//		exit(0);
        modfile = "spacedeb.mod";
	}
    else
    {
        modfile = argv[1];
    }

	mp_mod_player* modplayer = modplayer_create_from_file(modfile);
	if(modplayer == NULL)
		exit(1);
	printf("playing %s\n", modplayer->mod->name);

	return app_run( app_proc, modplayer, NULL, NULL, NULL );
}

//extern "C" int __stdcall WinMain( struct HINSTANCE__*, struct HINSTANCE__*, char*, int ) { return main( __argc, __argv ); }
//int __stdcall WinMain( struct HINSTANCE__* hInstance, struct HINSTANCE__* hPrevInstance, LPSTR argv, int argc) { return main( __argc, __argv ); }
