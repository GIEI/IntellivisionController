/* Wi-Fi TCP and Bluetooth Classic RFCOMM phone-controller transports. */
#ifndef FREEINTV_REMOTE_INPUT_H
#define FREEINTV_REMOTE_INPUT_H

#include <stdint.h>
#include <stddef.h>

#define REMOTE_INPUT_PORT 55355

enum remote_input_button
{
	REMOTE_UP = 0,
	REMOTE_DOWN,
	REMOTE_LEFT,
	REMOTE_RIGHT,
	REMOTE_ACTION_LEFT,
	REMOTE_ACTION_RIGHT,
	REMOTE_ACTION_TOP,
	REMOTE_KEY_1,
	REMOTE_KEY_2,
	REMOTE_KEY_3,
	REMOTE_KEY_4,
	REMOTE_KEY_5,
	REMOTE_KEY_6,
	REMOTE_KEY_7,
	REMOTE_KEY_8,
	REMOTE_KEY_9,
	REMOTE_KEY_CLEAR,
	REMOTE_KEY_0,
	REMOTE_KEY_ENTER,
	REMOTE_START,
	REMOTE_SELECT,
	REMOTE_BUTTON_COUNT
};

typedef struct remote_input_state
{
	uint32_t buttons;
	int16_t axis_x;
	int16_t axis_y;
	int connected;
} remote_input_state_t;

void remote_input_set_enabled(int enabled);
void remote_input_set_transport(const char *transport);
int remote_input_uses_bluetooth(void);
void remote_input_set_pairing_code(const char *code);
void remote_input_get_host_address(char *buffer, size_t buffer_size);
void remote_input_set_overlay(const uint8_t *data, size_t data_size,
	const char *mime_type);
void remote_input_poll(void);
remote_input_state_t remote_input_get_state(void);

#endif
