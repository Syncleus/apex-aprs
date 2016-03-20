#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""This is the entry point for the application, just a sandbox right now."""
import aprs.aprs_kiss

__author__ = 'Jeffrey Phillips Freeman WI2ARD <freemo@gmail.com>'
__license__ = 'Apache License, Version 2.0'
__copyright__ = 'Copyright 2016, Syncleus, Inc. and contributors'

import time
import signal
import sys
import kiss.constants
import aprs
import aprs.util
import threading
import configparser

port_map = {}
config = configparser.ConfigParser()
config.read('apex.cfg')
for section in config.sections():
    if section.startswith("TNC "):
        tnc_name = section.split(" ")[1]
        kiss_tnc = aprs.AprsKiss(com_port=config.get(section, 'com_port'), baud=config.get(section, 'baud'))
        kiss_init_string = config.get(section,'kiss_init')
        if kiss_init_string == 'MODE_INIT_W8DED':
            kiss_tnc.start(kiss.constants.MODE_INIT_W8DED)
        elif kiss_init_string == 'MODE_INIT_KENWOOD_D710':
            kiss_tnc.start(kiss.constants.MODE_INIT_KENWOOD_D710)
        else:
            raise Exception("KISS init mode not specified")
        for port in range(1, 1+int(config.get(section, 'port_count'))):
            port_name = tnc_name + '-' + str(port)
            port_section = 'PORT ' + port_name
            port_identifier = config.get(port_section, 'identifier')
            port_net = config.get(port_section, 'net')
            tnc_port = int(config.get(port_section, 'tnc_port'))
            beacon_path = config.get(port_section, 'beacon_path')
            beacon_text = config.get(port_section, 'beacon_text')
            status_path = config.get(port_section, 'status_path')
            status_text = config.get(port_section, 'status_text')
            port_map[port_name] = {'identifier':port_identifier, 'net':port_net, 'tnc':kiss_tnc, 'tnc_port':tnc_port, 'beacon_path':beacon_path, 'beacon_text':beacon_text, 'status_path':status_path, 'status_text':status_text}
aprsis_callsign = config.get('APRS-IS', 'callsign')
aprsis_password = config.get('APRS-IS', 'password')
aprsis_server = config.get('APRS-IS', 'server')
aprsis_server_port = config.get('APRS-IS', 'server_port')
aprsis = aprs.AprsInternetService(aprsis_callsign, aprsis_password)
aprsis.connect(aprsis_server, aprsis_server_port)

def sigint_handler(signal, frame):
    for port in port_map:
        port['tnc'].close()
    sys.exit(0)

signal.signal(signal.SIGINT, sigint_handler)

print("Press ctrl + c at any time to exit")

def digipeat(frame, recv_port, recv_port_name):
    # Can't digipeat anything when you are the source
    for port in port_map.values():
        if frame and frame['source'] is port['identifier']:
            return

    # can't digipeat things we already digipeated.
    for hop in frame['path']:
        if hop.startswith('WI2ARD') and hop.endswith('*'):
            return

    for hop_index in range(0,len(frame['path'])):
        hop = frame['path'][hop_index]
        if hop[-1] is not '*':
            split_hop = hop.split('-')
            node = split_hop[0].upper()
            if len(split_hop) >= 2 and split_hop[1]:
                ssid = int(split_hop[1])
            else:
                ssid = 0

            for port_name in port_map.keys():
                port = port_map[port_name]
                split_port_identifier = port['identifier'].split('-')
                port_callsign = split_port_identifier[0].upper()
                if len(split_port_identifier) >= 2 and split_port_identifier[1]:
                    port_ssid = int(split_port_identifier[1])
                else:
                    port_ssid = 0

                if node == port_callsign and ssid == port_ssid:
                    if ssid is 0:
                        frame['path'][hop_index] = port_callsign + '*'
                    else:
                        frame['path'][hop_index] = port['identifier'] + '*'
                    port['tnc'].write(frame, port['tnc_port'])
                    aprsis.send(frame)
                    print(port_name + " >> " + aprs.util.format_aprs_frame(frame))
                    return

            if node.startswith('WIDE') and ssid > 1:
                frame['path'] = frame['path'][:hop_index-1] + [recv_port['identifier'] + '*'] + [node + "-" + str(ssid-1)] + frame['path'][hop_index+1:]
                recv_port['tnc'].write(frame, port['tnc_port'])
                aprsis.send(frame)
                print(recv_port_name + " >> " + aprs.util.format_aprs_frame(frame))
                return
            elif node.startswith('WIDE') and ssid is 1:
                frame['path'] = frame['path'][:hop_index-1] + [recv_port['identifier'] + '*'] + [node + "*"] + frame['path'][hop_index+1:]
                recv_port['tnc'].write(frame, port['tnc_port'])
                aprsis.send(frame)
                print(recv_port_name + " >> " + aprs.util.format_aprs_frame(frame))
                return
            elif node.startswith('WIDE') and ssid is 0:
                frame['path'][hop_index] = node + "*"
                # no return
    #If we didnt digipeat it then we didn't modify the frame, send it to aprsis as-is
    aprsis.send(frame)

def kiss_reader_thread():
    print("Begining kiss reader thread...")
    while 1:
        something_read = False
        try:
            for port_name in port_map.keys():
                port = port_map[port_name]
                frame = port['tnc'].read()
                if frame:
                    something_read = True
                    digipeat(frame, port, port_name)
                    formatted_aprs = aprs.util.format_aprs_frame(frame)
                    print(port_name + " << " + formatted_aprs)
        except Exception as ex:
            # We want to keep this thread alive so long as the application runs.
            print("caught exception while reading packet: " + str(ex))

        if something_read is False:
            time.sleep(1)

threading.Thread(target=kiss_reader_thread, args=()).start()
while 1 :
    for port_name in port_map.keys():
        port = port_map[port_name]

        beacon_frame = {'source':port['identifier'], 'destination': 'APRS', 'path':port['beacon_path'].split(','), 'text': list(port['beacon_text'].encode('ascii'))}
        port['tnc'].write(beacon_frame, port['tnc_port'])
        print(port_name + " >> " + aprs.util.format_aprs_frame(beacon_frame))

        status_frame = {'source':port['identifier'], 'destination': 'APRS', 'path':port['status_path'].split(','), 'text': list(port['status_text'].encode('ascii'))}
        port['tnc'].write(status_frame, port['tnc_port'])
        print(port_name + " >> " + aprs.util.format_aprs_frame(status_frame))
    time.sleep(600)

