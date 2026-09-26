#include "remote_input.h"

#include <string.h>

#if defined(_WIN32)
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <stdio.h>

#define REMOTE_PACKET_SIZE 16
#define REMOTE_BUFFER_SIZE 512
#define REMOTE_TIMEOUT_MS 500
#define REMOTE_CODE_MAX 31

static SOCKET listener_socket = INVALID_SOCKET;
static SOCKET client_socket = INVALID_SOCKET;
static int winsock_started = 0;
static int remote_enabled = 0;
static int packet_buffer_size = 0;
static uint8_t packet_buffer[REMOTE_BUFFER_SIZE];
static uint32_t last_sequence = 0;
static int has_sequence = 0;
static DWORD last_packet_time = 0;
static remote_input_state_t remote_state;
static char pairing_code[REMOTE_CODE_MAX + 1] = "482731";
static int authenticated = 0;

static int is_private_ipv4(uint32_t address)
{
	uint32_t host = ntohl(address);
	return (host >> 24) == 10 ||
		(host >> 20) == 0xAC1 ||
		(host >> 16) == 0xC0A8;
}

void remote_input_get_host_address(char *buffer, size_t buffer_size)
{
	char hostname[256];
	struct addrinfo hints;
	struct addrinfo *addresses = NULL;
	struct addrinfo *entry;
	size_t used = 0;
	if (!buffer || buffer_size == 0)
		return;
	buffer[0] = '\0';
	if (listener_socket == INVALID_SOCKET)
		return;
	if (gethostname(hostname, sizeof(hostname)) != 0)
		return;
	memset(&hints, 0, sizeof(hints));
	hints.ai_family = AF_INET;
	hints.ai_socktype = SOCK_STREAM;
	if (getaddrinfo(hostname, NULL, &hints, &addresses) != 0)
		return;
	for (entry = addresses; entry && used < buffer_size - 1; entry = entry->ai_next)
	{
		const struct sockaddr_in *ipv4 = (const struct sockaddr_in *)entry->ai_addr;
		char ip[INET_ADDRSTRLEN];
		char *cursor;
		if (!is_private_ipv4(ipv4->sin_addr.s_addr) ||
			!inet_ntop(AF_INET, &ipv4->sin_addr, ip, sizeof(ip)))
			continue;
		if (used > 0)
		{
			if (used + 2 >= buffer_size)
				break;
			buffer[used++] = ',';
			buffer[used++] = ' ';
			buffer[used] = '\0';
		}
		for (cursor = ip; *cursor && used + 1 < buffer_size; ++cursor)
			buffer[used++] = *cursor;
		buffer[used] = '\0';
	}
	freeaddrinfo(addresses);
}

static void close_client(void)
{
	if (client_socket != INVALID_SOCKET)
	{
		closesocket(client_socket);
		client_socket = INVALID_SOCKET;
	}
	packet_buffer_size = 0;
	has_sequence = 0;
	authenticated = 0;
	last_packet_time = 0;
	memset(&remote_state, 0, sizeof(remote_state));
}

static void stop_listener(void)
{
	close_client();
	if (listener_socket != INVALID_SOCKET)
	{
		closesocket(listener_socket);
		listener_socket = INVALID_SOCKET;
	}
	if (winsock_started)
	{
		WSACleanup();
		winsock_started = 0;
	}
}

static int make_nonblocking(SOCKET socket_handle)
{
	u_long nonblocking = 1;
	return ioctlsocket(socket_handle, FIONBIO, &nonblocking) == 0;
}

static uint32_t read_u32_le(const uint8_t *p)
{
	return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
		((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static int16_t read_i16_le(const uint8_t *p)
{
	uint16_t value = (uint16_t)p[0] | ((uint16_t)p[1] << 8);
	return (int16_t)value;
}

static void consume_packet(void)
{
	uint32_t sequence = read_u32_le(packet_buffer + 4);
	uint32_t buttons = read_u32_le(packet_buffer + 8);
	int32_t axis_x = read_i16_le(packet_buffer + 12);
	int32_t axis_y = read_i16_le(packet_buffer + 14);

	if (!has_sequence || (int32_t)(sequence - last_sequence) > 0)
	{
		uint32_t valid_buttons = (1u << REMOTE_BUTTON_COUNT) - 1u;
		last_sequence = sequence;
		has_sequence = 1;
		remote_state.buttons = buttons & valid_buttons;
		remote_state.axis_x = (int16_t)axis_x;
		remote_state.axis_y = (int16_t)axis_y;
		remote_state.connected = 1;
		last_packet_time = GetTickCount();
	}
}

static void process_buffer(void)
{
	int offset = 0;
	while (packet_buffer_size - offset >= REMOTE_PACKET_SIZE)
	{
		if (memcmp(packet_buffer + offset, "FIV1", 4) == 0)
		{
			memmove(packet_buffer, packet_buffer + offset, (size_t)(packet_buffer_size - offset));
			packet_buffer_size -= offset;
			consume_packet();
			memmove(packet_buffer, packet_buffer + REMOTE_PACKET_SIZE,
				(size_t)(packet_buffer_size - REMOTE_PACKET_SIZE));
			packet_buffer_size -= REMOTE_PACKET_SIZE;
			offset = 0;
		}
		else
			offset++;
	}
	if (offset > 0)
	{
		memmove(packet_buffer, packet_buffer + offset, (size_t)(packet_buffer_size - offset));
		packet_buffer_size -= offset;
	}
}

void remote_input_set_pairing_code(const char *code)
{
	if (code && *code)
	{
		strncpy(pairing_code, code, REMOTE_CODE_MAX);
		pairing_code[REMOTE_CODE_MAX] = '\0';
	}
}

static void poll_listener(void)
{
	if (listener_socket == INVALID_SOCKET)
		return;

	if (client_socket == INVALID_SOCKET)
	{
		SOCKET accepted = accept(listener_socket, NULL, NULL);
		if (accepted != INVALID_SOCKET)
		{
			BOOL no_delay = TRUE;
			if (!make_nonblocking(accepted))
				closesocket(accepted);
			else
			{
				setsockopt(accepted, IPPROTO_TCP, TCP_NODELAY,
					(const char *)&no_delay, sizeof(no_delay));
				client_socket = accepted;
				packet_buffer_size = 0;
				has_sequence = 0;
				authenticated = 0;
			}
		}
	}

	if (client_socket != INVALID_SOCKET && packet_buffer_size < REMOTE_BUFFER_SIZE)
	{
		int received = recv(client_socket,
			(char *)packet_buffer + packet_buffer_size,
			REMOTE_BUFFER_SIZE - packet_buffer_size, 0);
		if (received > 0)
		{
			if (!authenticated)
			{
				char received_code[REMOTE_CODE_MAX + 1];
				int code_length = (int)strlen(pairing_code);
				int total = packet_buffer_size + received;
				packet_buffer_size = total;
				if (total >= code_length + 1)
				{
					memcpy(received_code, packet_buffer, (size_t)code_length);
					received_code[code_length] = '\0';
					if (memcmp(received_code, pairing_code, (size_t)code_length) == 0 &&
						packet_buffer[code_length] == '\n')
					{
						authenticated = 1;
						memmove(packet_buffer, packet_buffer + code_length + 1,
							(size_t)(total - code_length - 1));
						packet_buffer_size = total - code_length - 1;
						process_buffer();
					}
					else
						close_client();
				}
			}
			else
			{
				packet_buffer_size += received;
				process_buffer();
			}
		}
		else if (received == 0 || WSAGetLastError() != WSAEWOULDBLOCK)
			close_client();
	}

	if (remote_state.connected && (DWORD)(GetTickCount() - last_packet_time) > REMOTE_TIMEOUT_MS)
		close_client();
}

void remote_input_set_enabled(int enabled)
{
	struct sockaddr_in address;
	WSADATA data;
	SOCKET socket_handle;

	remote_enabled = enabled != 0;
	if (!remote_enabled)
	{
		stop_listener();
		return;
	}
	if (listener_socket != INVALID_SOCKET)
		return;

	if (WSAStartup(MAKEWORD(2, 2), &data) != 0)
		return;
	winsock_started = 1;
	socket_handle = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
	if (socket_handle == INVALID_SOCKET || !make_nonblocking(socket_handle))
	{
		if (socket_handle != INVALID_SOCKET)
			closesocket(socket_handle);
		stop_listener();
		return;
	}

	memset(&address, 0, sizeof(address));
	address.sin_family = AF_INET;
	/* LAN transport: phone connects directly to the PC's local IP. */
	address.sin_addr.s_addr = htonl(INADDR_ANY);
	address.sin_port = htons(REMOTE_INPUT_PORT);
	if (bind(socket_handle, (struct sockaddr *)&address, sizeof(address)) == SOCKET_ERROR ||
		listen(socket_handle, 1) == SOCKET_ERROR)
	{
		closesocket(socket_handle);
		stop_listener();
		return;
	}
	listener_socket = socket_handle;
}

void remote_input_poll(void)
{
	if (remote_enabled)
		poll_listener();
}

remote_input_state_t remote_input_get_state(void)
{
	return remote_state;
}

#else

static remote_input_state_t remote_state;
void remote_input_set_enabled(int enabled) { (void)enabled; }
void remote_input_set_pairing_code(const char *code) { (void)code; }
void remote_input_get_host_address(char *buffer, size_t buffer_size)
{
	if (buffer && buffer_size > 0)
		buffer[0] = '\0';
}
void remote_input_poll(void) { }
remote_input_state_t remote_input_get_state(void) { return remote_state; }

#endif
