#!/usr/bin/perl

#   Copyright (C) 2010 Mauro Carvalho Chehab <mchehab@redhat.com>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, version 2 of the License.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
# This small script parses register dumps generated by cx231xx driver
# with debug options enabled, generating a source code with the results
# of the dump.
#
# To use it, you may modprobe cx231xx with reg_debug=1, and do:
# dmesg | ./parse_em28xx.pl
#
# Also, there are other utilities that produce similar outputs, and it
# is not hard to parse some USB analyzers log into the expected format.
#

use strict;

sub parse_i2c($$$$$$)
{
	my $reqtype = shift;
	my $req = shift;
	my $wvalue = shift;
	my $windex = shift;
	my $wlen = shift;
	my $payload = shift;

	my $daddr = $wvalue >> 9;
	my $reserved = ($wvalue >>6 ) & 0x07;
	my $period = ($wvalue >> 4) & 0x03;
	my $addr_len = ($wvalue >> 2) & 0x03;
	my $nostop = ($wvalue >>1) & 0x01;
	my $sync = $wvalue & 0x01;

	if ($nostop) {
		$nostop="nostop ";
	} else {
		$nostop="";
	}
	if ($sync) {
		$sync="sync ";
	} else {
		$sync="";
	}
	my $type;
	my $i2c_channel;
	if ($reqtype > 128) {
		$type = "IN ";
		$i2c_channel = $req - 4;
	} else {
		$type = "OUT";
		$i2c_channel = $req;
	}
	if ($period == 0) {
		$period = "1Mbps";
	} elsif ($period == 1) {
		$period = "400kbps";
	} elsif ($period == 2) {
		$period = "100kbps";
	} else {
		$period = "???kbps";
	}
	printf("$type i2c channel#%d daddr 0x%02x %s addr_len %d %s%slen %d = ",
		$i2c_channel, $daddr, $period, $addr_len, $nostop, $sync,
		$wlen);
	if ($addr_len == 1) {
		printf("(saddr)%02x ", $windex & 0xff);
	} elsif ($addr_len == 2) {
		printf("(saddr)%04x ", $windex);
	}
	printf("$payload\n");
}

sub parse_gpio($$$$$$)
{
	my $reqtype = shift;
	my $req = shift;
	my $wvalue = shift;
	my $windex = shift;
	my $wlen = shift;
	my $payload = shift;

	my $type;
	if ($req == 8) {
		$type .= "GET gpio";
	} elsif ($req == 9) {
		$type .= "SET gpio";
	} elsif ($req == 0xa) {
		$type .= "SET gpie";
	} elsif ($req == 0xb) {
		$type .= "SET gpie";
	}

	my $gpio_bit = $wvalue << 16 & $windex;

	printf("$type: Reqtype %3d Req %3d 0x%04x len %d val = %s\n",
		$reqtype, $req, $gpio_bit, $wlen, $payload);
}

while (<>) {
	tr/A-F/a-f/;
	if (m/([4c]0) ([0-9a-f].) ([0-9a-f].) ([0-9a-f].) ([0-9a-f].) ([0-9a-f].) ([0-9a-f].) ([0-9a-f].)[\<\>\s]+(.*)/) {
		my $reqtype = hex($1);
		my $req = hex($2);
		my $wvalue = hex("$4$3");
		my $windex = hex("$6$5");
		my $wlen = hex("$8$7");
		my $payload = $9;

		if ($reqtype > 128 && (($req >= 4) && ($req <= 6))) {
			parse_i2c($reqtype, $req, $wvalue, $windex, $wlen, $payload);
		} elsif ($req < 3) {
			parse_i2c($reqtype, $req, $wvalue, $windex, $wlen, $payload);
		} elsif ($req >= 8 && $req <= 0xb) {
			parse_gpio($reqtype, $req, $wvalue, $windex, $wlen, $payload);
		} else {
			printf("Reqtype: %3d, Req %3d, wValue: 0x%04x, wIndex 0x%04x, wlen %d: %s\n",
				$reqtype, $req, $wvalue, $windex, $wlen, $payload);
		}
	}
}