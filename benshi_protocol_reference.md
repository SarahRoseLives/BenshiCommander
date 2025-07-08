This document details the Benshi radio communication protocol as implemented by the benlink library. It's designed to be comprehensive enough for an AI to understand and use as a reference for developing compatible software.

The protocol facilitates communication with Benshi radios (like the Vero VR-N76, RadioOddity GA-5WB, and BTech UV-Pro) over two primary transport layers: Bluetooth Low Energy (BLE) and RFCOMM (Bluetooth Classic).

1. Transport Layers

Communication is handled differently depending on whether you're using BLE or RFCOMM.

1.1. Bluetooth Low Energy (BLE)

BLE is used for sending commands and receiving replies or events.

    Service UUID: 00001100-d102-11e1-9b23-00025b00a5a5

    Write Characteristic UUID: 00001101-d102-11e1-9b23-00025b00a5a5

        Client writes command messages to this characteristic.

        Writes must be sent with response request (write with response).

    Indicate Characteristic UUID: 00001102-d102-11e1-9b23-00025b00a5a5

        The radio sends replies and event notifications via this characteristic using indications.

        The client must subscribe to indications to receive data.

On BLE, the payload for both writing and receiving is a raw protocol.Message object, serialized to bytes.

1.2. RFCOMM (Serial Port Profile)

RFCOMM is used for both command/control and audio, but on separate channels.

1.2.1. Command Channel

When sending protocol.Message commands over RFCOMM, they must be wrapped in a GaiaFrame.

    GaiaFrame Structure:

        The frame is designed to encapsulate data for serial communication. The structure is as follows:

Field
	

Length (Bytes)
	

Description

Start of Frame
	

1
	

Always 0xFF.

Version
	

1
	

Always 0x01.

Flags
	

1
	

A bitmask of GaiaFlags. Typically 0 (NONE). If bit 0 is set, a checksum is present.

Payload Length
	

1
	

Length of the Data field, excluding the 4 command header bytes.

Data
	

4 + Payload Length
	

The serialized protocol.Message object.

Checksum
	

1 (Optional)
	

An 8-bit checksum, present only if the CHECKSUM flag is set.

1.2.2. Audio Channel

The audio channel is used for transmitting and receiving real-time audio.

    Encoding: The audio data is encoded using the SBC (Sub-band Codec). The benlink examples use a sample rate of 32000 Hz.

    Framing: All audio messages are wrapped in frames delimited by 0x7e.

    Byte Escaping (Stuffing): Within the frame (between the 0x7e delimiters), if the data contains a 0x7e or 0x7d byte, it is escaped. The escape character is 0x7d, and the following byte is XORed with 0x20.

        0x7e becomes 0x7d 0x5e

        0x7d becomes 0x7d 0x5d

    Audio Messages:

        AudioData: Carries the SBC-encoded audio payload.

        AudioEnd: Signals the end of a transmission.

        AudioAck: Acknowledgment message.

The structure of a deserialized audio message is:

Field
	

Length (Bytes)
	

Description

Type
	

1
	

0x00 for AudioData, 0x01 for AudioEnd, 0x02 for AudioAck.

Data
	

Variable
	

The SBC payload for AudioData, or padding for other types.

2. Core Command Protocol

All non-audio communication is managed through a request-reply and event notification system using a single message structure.

2.1. Message Structure

Every command, reply, and event is encapsulated in a Message object. This is the fundamental data unit for the command protocol.

Field
	

Length (Bits)
	

Description

command_group
	

16
	

Identifies the category of the command. See CommandGroup enum.

is_reply
	

1
	

True (1) if the message is a reply from the radio, False (0) if it's a command from the client or an event from the radio.

command
	

15
	

The specific command ID. Its interpretation depends on command_group. See BasicCommand and ExtendedCommand enums.

body
	

Variable
	

The payload of the message. Its structure is determined by the command_group, command, and is_reply fields.

2.2. Interaction Flow

    Command-Reply: The client sends a Message with is_reply = False. The radio processes the command and responds with a corresponding Message that has the same command_group and command ID, but with is_reply = True. The body of the reply contains the requested data or a status code.

    Events (Notifications): The radio can spontaneously send Message objects to the client. For these, is_reply = False and the command is typically EVENT_NOTIFICATION. The client must first subscribe to events using the REGISTER_NOTIFICATION command.

2.3. Core Enumerations

CommandGroup (16-bit integer)

Name
	

Value
	

Description

BASIC
	

2
	

Standard commands for radio operation.

EXTENDED
	

10
	

Less common or advanced commands.

BasicCommand (15-bit integer, used when command_group is BASIC)

Name
	

Value
	

Description

GET_DEV_INFO
	

4
	

Get device hardware and firmware information.

READ_STATUS
	

5
	

Read power-related status (battery voltage, level).

REGISTER_NOTIFICATION
	

6
	

Subscribe to an event type.

EVENT_NOTIFICATION
	

9
	

An event notification from the radio.

READ_SETTINGS
	

10
	

Read the main radio settings block.

WRITE_SETTINGS
	

11
	

Write to the main radio settings block.

READ_RF_CH
	

13
	

Read the configuration of a specific channel.

WRITE_RF_CH
	

14
	

Write the configuration for a specific channel.

GET_HT_STATUS
	

20
	

Get the main operational status of the radio.

HT_SEND_DATA
	

31
	

Send a TNC data fragment (for APRS/BSS).

READ_BSS_SETTINGS
	

33
	

Read beacon (APRS/BSS) settings.

WRITE_BSS_SETTINGS
	

34
	

Write beacon (APRS/BSS) settings.

SET_PHONE_STATUS
	

51
	

Inform the radio of the phone's link status.

GET_POSITION
	

76
	

Get the last known GPS position from the radio.

(...and many others)
		

ReplyStatus (8-bit integer, common in reply bodies)

Name
	

Value
	

Description

SUCCESS
	

0
	

The command was successful.

NOT_SUPPORTED
	

1
	

The command is not supported by the radio.

INVALID_PARAMETER
	

5
	

A parameter in the command body was invalid.

INCORRECT_STATE
	

6
	

The radio was not in the correct state to execute the command.

(...and others)
		

3. Command and Data Structure Reference

This section details the body structure for key commands and the data objects they use. All structures are defined as Bitfield classes.

3.1. Device Information (GET_DEV_INFO)

    Command: BasicCommand.GET_DEV_INFO (4)

    Request Body (GetDevInfoBody): An 8-bit integer with a constant value of 3.

    Reply Body (GetDevInfoReplyBody):

        reply_status (8 bits): See ReplyStatus enum.

        dev_info (variable): A DevInfo structure, present only if reply_status is SUCCESS.

    DevInfo Structure:

Field
	

Length (Bits)
	

Type
	

Description

vendor_id
	

8
	

int
	

Manufacturer ID.

product_id
	

16
	

int
	

Product model ID.

hw_ver
	

8
	

int
	

Hardware version.

soft_ver
	

16
	

int
	

Firmware version.

support_radio
	

1
	

bool
	

True if radio functions are supported.

support_medium_power
	

1
	

bool
	

True if a medium power setting exists.

support_dmr
	

1
	

bool
	

True if DMR is supported.

channel_count
	

8
	

int
	

The total number of channels available (e.g., 255).

freq_range_count
	

4
	

int
	

Number of supported frequency ranges.

(...and other flags)
			

3.2. Radio Settings (READ_SETTINGS / WRITE_SETTINGS)

    Commands: READ_SETTINGS (10), WRITE_SETTINGS (11)

    Read Request: Empty body.

    Read Reply / Write Request (Settings): A large bitfield containing dozens of radio settings.

    Write Reply: An 8-bit reply_status.

    Settings Structure (Partial):

Field
	

Length (Bits)
	

Type
	

Description

channel_a
	

8
	

int
	

The channel number for VFO A (split into 4+4 bits).

channel_b
	

8
	

int
	

The channel number for VFO B (split into 4+4 bits).

scan
	

1
	

bool
	

True if scanning is active.

squelch_level
	

4
	

int
	

Squelch level (0-9).

tail_elim
	

1
	

bool
	

Squelch tail elimination enabled.

mic_gain
	

3
	

int
	

Microphone gain level.

auto_power_off
	

3
	

int
	

Auto Power Off timer setting.

(...and many more)
			

3.3. Channel Settings (READ_RF_CH / WRITE_RF_CH)

    Commands: READ_RF_CH (13), WRITE_RF_CH (14)

    Read Request (ReadRFChBody): Contains the 8-bit channel_id to read.

    Read Reply / Write Request (RfCh): The full configuration for a single channel.

    Write Reply: reply_status (8 bits) and channel_id (8 bits).

    RfCh Structure (Partial):

Field
	

Length (Bits)
	

Type / Mapping
	

Description

channel_id
	

8
	

int
	

The channel index (0-254).

tx_mod
	

2
	

ModulationType enum
	

FM, AM, DMR.

tx_freq
	

30
	

float (scaled by 1e-6)
	

Transmit frequency in MHz.

rx_mod
	

2
	

ModulationType enum
	

Receive modulation.

rx_freq
	

30
	

float (scaled by 1e-6)
	

Receive frequency in MHz.

tx_sub_audio
	

16
	

float or DCS
	

CTCSS tone or DCS code for TX. 0 for none.

rx_sub_audio
	

16
	

float or DCS
	

CTCSS tone or DCS code for RX. 0 for none.

bandwidth
	

1
	

BandwidthType enum
	

NARROW or WIDE.

tx_disable
	

1
	

bool
	

True to disable transmit on this channel.

name_str
	

80 (10 bytes)
	

string
	

Channel name (UTF-8).

3.4. Radio Status (GET_HT_STATUS)

    Command: BasicCommand.GET_HT_STATUS (20)

    Request Body: Empty.

    Reply Body (GetHtStatusReplyBody):

        reply_status (8 bits): See ReplyStatus enum.

        status (variable): A Status or StatusExt structure, present if reply_status is SUCCESS. Newer firmware uses StatusExt.

    StatusExt Structure:

Field
	

Length (Bits)
	

Type / Mapping
	

Description

is_power_on
	

1
	

bool
	

True if radio is powered on.

is_in_tx
	

1
	

bool
	

True if radio is currently transmitting.

is_sq
	

1
	

bool
	

True if squelch is open (signal present).

is_in_rx
	

1
	

bool
	

True if radio is receiving (squelch open + tone match).

double_channel
	

2
	

ChannelType enum
	

OFF, A, or B for dual watch status.

is_scan
	

1
	

bool
	

True if radio is scanning.

curr_ch_id
	

8
	

int
	

The currently active channel ID (split into 4+4 bits).

is_gps_locked
	

1
	

bool
	

True if GPS has a fix.

rssi
	

4
	

float (scaled)
	

Received Signal Strength Indicator.

curr_region
	

6
	

int
	

Current channel region/zone.

3.5. TNC Data (HT_SEND_DATA)

    Command: BasicCommand.HT_SEND_DATA (31)

    Request Body (HTSendDataBody): Contains one TncDataFragment.

    Reply Body (HTSendDataReplyBody): An 8-bit reply_status.

    TncDataFragment Structure:

Field
	

Length (Bits)
	

Type
	

Description

is_final_fragment
	

1
	

bool
	

True if this is the last fragment of a message.

with_channel_id
	

1
	

bool
	

True if an optional channel_id is appended.

fragment_id
	

6
	

int
	

Sequence number for the fragment.

data
	

Variable
	

The raw data payload for the fragment.
	

channel_id
	

8 (optional)
	

int
	

Channel to transmit on (present if with_channel_id is true).

3.6. Event Notifications

    Trigger: Radio sends an EVENT_NOTIFICATION message (BasicCommand 9).

    Body (EventNotificationBody):

        event_type (8 bits): The type of event that occurred. See EventType enum.

        event (variable): A structure whose type depends on event_type.

    EventType Enum (Partial):

Name
	

Value
	

Payload Structure

HT_STATUS_CHANGED
	

1
	

HTStatusChangedEvent (contains a Status object)

DATA_RXD
	

2
	

DataRxdEvent (contains a TncDataFragment)

HT_CH_CHANGED
	

5
	

HTChChangedEvent (contains an RfCh object)

HT_SETTINGS_CHANGED
	

6
	

HTSettingsChangedEvent (contains a Settings object)