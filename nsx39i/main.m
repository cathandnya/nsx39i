//
//  main.m
//  nsx39i
//
//  Created by semnil on 4/23/14.
//  Copyright (c) 2014 semnil. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>

#include <stdio.h>
#include <unistd.h>

#import "pronounce_table.h"


#define DEVICE_NAME CFSTR("NSX-39 ")
#define PORT_NAME CFSTR("NSX-39voiceOut")


MIDIEndpointRef getEndpointWithDisplayName(CFStringRef name)
{
    NSUInteger count = MIDIGetNumberOfDestinations();
    
    for (int i = 0;i < count;i++) {
        MIDIEndpointRef foundObj = MIDIGetDestination(i);
        CFStringRef endPointName;
        MIDIObjectGetStringProperty(foundObj, kMIDIPropertyDisplayName, &endPointName);
        if (endPointName && CFStringCompare(name , endPointName, 0) == kCFCompareEqualTo)
            return (MIDIEndpointRef)foundObj;
    }
    
    return 0;
}

MIDIClientRef getMidiClient()
{
    MIDIClientRef midiClient;
    
    MIDIClientCreate(PORT_NAME, NULL, NULL, &midiClient);
    
    return midiClient;
}

MIDIPortRef getOutPutPort()
{
    MIDIPortRef outPort;
    
    MIDIOutputPortCreate(getMidiClient(), PORT_NAME, &outPort);
    
    return outPort;
}

MIDIPacketList getMidiPacketList(Byte *message, UInt16 length)
{
    MIDIPacketList packetList;
    
    packetList.numPackets = 1;
    
    MIDIPacket* firstPacket = &packetList.packet[0];
    
    firstPacket->timeStamp = 0;
    
    int maxLen = sizeof(firstPacket->data);
    if (length > maxLen)
        length = maxLen;
    firstPacket->length = length;
    
    for (UInt16 i = 0;i < length;i++) {
        firstPacket->data[i] = message[i];
    }
    
    return packetList;
}

void sendNote(MIDIEndpointRef endPoint, Byte *message, UInt16 length)
{
    MIDIPacketList packetList = getMidiPacketList(message, length);
    
    MIDISend(getOutPutPort(), endPoint, &packetList);
}

BOOL sendPronounce(MIDIEndpointRef endPoint, NSString *str) {
	int num = GetPronounceNumber(str);
	if (num >= 0) {
		// F0 43 79 09 11 0A 00 ** F7
		Byte msg[9];
		msg[0] = 0xF0;
		msg[1] = 0x43;
		msg[2] = 0x79;
		msg[3] = 0x09;
		msg[4] = 0x11;
		msg[5] = 0x0A;
		msg[6] = 0x00;
		msg[7] = num;
		msg[8] = 0xF7;
		sendNote(endPoint, msg, 9);
		return YES;
	} else {
		return NO;
	}
}

void sendVoice(MIDIEndpointRef endPoint, NSString *pronounce, int scale, float duration, float base) {
	Byte msg[3];

	if (sendPronounce(endPoint, pronounce)) {
		msg[0] = 0x90;
		msg[1] = scale;
		msg[2] = 0x64;
		sendNote(endPoint, msg, 3);
	}
	
	[NSThread sleepForTimeInterval:base * duration];

	msg[0] = 0xB0;
	msg[1] = 0x78;
	msg[2] = 0x00;
	sendNote(endPoint, msg, 3);
}

#if 1

int main(int argc, char **argv)
{
    CFStringRef endPointName = DEVICE_NAME;
    MIDIEndpointRef endPoint = getEndpointWithDisplayName(endPointName);
    if (endPoint == 0) {
        fprintf(stdout, "%s not found.\n", CFStringGetCStringPtr(DEVICE_NAME, kCFStringEncodingASCII));
        return -1;
    }
	
	float base = 0.5;
	sendVoice(endPoint, @"あ", 0x43, 1.0 / 2.0, base);
	sendVoice(endPoint, @"い", 0x43, 1.0 / 2.0, base);
	sendVoice(endPoint, @"ね", 0x43, 1.0 / 2.0, base);
	sendVoice(endPoint, @"と", 0x43, 1.0 / 2.0, base);
	sendVoice(endPoint, @"こ", 0x48, 1.0, base);
	sendVoice(endPoint, @"ぷ", 0x45, 1.0, base);
	sendVoice(endPoint, @"", 0x3c, 1.0, base);
	sendVoice(endPoint, @"さ", 0x43, 1.0 / 2.0, base);
	sendVoice(endPoint, @"い", 0x43, 1.0 / 2.0, base);
	sendVoice(endPoint, @"た", 0x3c, 1.0 / 2.0, base);
	sendVoice(endPoint, @"ま", 0x3c, 1.0 / 2.0, base);
	
    MIDIEndpointDispose(endPoint);
    return 0;
}

#else

int main(int argc, char **argv)
{
    int result, mode = 0;
    Byte read_data;
    char read_buf[3], *read_param;
    Byte send_data[256];
    UInt16 len = 0, buf_ptr = 0;
    FILE *fp = stdin;
    
    CFStringRef endPointName = DEVICE_NAME;
    MIDIEndpointRef endPoint = getEndpointWithDisplayName(endPointName);
    
    if (endPoint == 0) {
        fprintf(stdout, "%s not found.\n", CFStringGetCStringPtr(DEVICE_NAME, kCFStringEncodingASCII));
        return -1;
    }
    
    while ((result = getopt(argc, argv, "s:S")) != -1) {
        switch (result) {
            case 's':
                // binary data read from a file
                fp = fopen(optarg, "rb");
                if (fp == NULL) {
                    fprintf(stdout, "file cannot open.\n");
                    return -2;
                }
                break;
                
            case 'S':
                // convert to binary from the hex string
                if (optind < argc && argv[optind][0] != '\0') {
                    read_param = argv[optind];
                    
                    // convert to send data from a parameter string
                    for (int i = 0;i < strlen(read_param);) {
                        // skip white space
                        while (i < strlen(read_param) && read_param[i] == ' ')
                            i++;
                        
                        // from string to binary
                        read_buf[buf_ptr++] = read_param[i++];
                        if (buf_ptr == 2) {
                            send_data[len++] = strtol(read_buf, NULL, 16);
                            buf_ptr = 0;
                        }
                        
                        // skip white space
                        while (i < strlen(read_param) && read_param[i] == ' ')
                            i++;
                    }
                    goto SEND_DATA;
                } else {
                    // real time converting and sending
                    mode = 1;
                    // print a prompt
                    fprintf(stdout, "> ");
                }
                break;
                
            case '?':
                fprintf(stdout, "unknown parameter.\n");
            default:
                goto MIDI_ENDPOINT_DISPOSE;
        }
    }
    
    while (fp != NULL && fscanf(fp, "%c", &read_data, NULL) != EOF) {
        switch (mode) {
            case 1:
                // convert to send data from the hex string of stdin
                if (read_data == 'q' || read_data == 'Q') {
                    // exit from the interactive mode
                    fprintf(stdout, "bye.\n");
                    goto MIDI_ENDPOINT_DISPOSE;
                } else if (read_data != '\n' && read_data != ' ' && read_data != '\t') {
                    read_buf[buf_ptr++] = read_data;
                    read_buf[buf_ptr] = '\0';
                    if (buf_ptr == 2) {
                        send_data[len++] = strtol(read_buf, NULL, 16);
                        buf_ptr = 0;
                    }
                } else if (read_data == '\n') {
                    // send data of one line
                    sendNote(endPoint, send_data, len);
                    buf_ptr = 0;
                    len = 0;
                    // print a prompt
                    fprintf(stdout, "> ");
                }
                break;
                
            default:
                // send data read from stdin
                send_data[len] = read_data;
                len++;
                if (len >= sizeof(send_data))
                    goto SEND_DATA;
                break;
        }
    };
    
SEND_DATA:
    if (send_data[0] != 0)
        sendNote(endPoint, send_data, len);
    
MIDI_ENDPOINT_DISPOSE:
    MIDIEndpointDispose(endPoint);
    
    if (fp != NULL && fp != stdin)
        fclose(fp);
    
    return 0;
}

#endif
