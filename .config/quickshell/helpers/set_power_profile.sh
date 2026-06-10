#!/bin/bash
busctl call net.hadess.PowerProfiles /net/hadess/PowerProfiles org.freedesktop.DBus.Properties.Set ssv net.hadess.PowerProfiles ActiveProfile s "$1"
