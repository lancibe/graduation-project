# -*- coding: utf-8 -*-
"""
Created on Mon Apr 10 14:58:00 2023

@author: 16095
"""

import serial

ser = serial.Serial()

ser.baudrate = 9600
ser.port = 'COM6'

ser.timeout = 1

ser.open()

while(True):
    res = ser.readline()
    print(res)
    
