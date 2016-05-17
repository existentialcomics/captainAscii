#!/usr/bin/perl
#
#
#
use IO::Socket::UNIX;
my $SOCK_PATH = "$ENV{HOME}/captainAscii.sock";
# Client:
my $client = IO::Socket::UNIX->new(
	Type => SOCK_STREAM(),
	Peer => $SOCK_PATH,
);

print $client "test\n";
print $client "test\n";
print $client "test";
print $client "test";
