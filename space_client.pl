#!/usr/bin/perl
#
#
#
use strict;
use warnings;
use Term::ANSIColor 4.00 qw(RESET color :constants256);
require Term::Screen;
use List::MoreUtils qw(zip);
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
		      clock_gettime clock_getres clock_nanosleep clock time);
use Data::Dumper;
use SpaceShip;
use IO::Socket::UNIX;
my $SOCK_PATH = "$ENV{HOME}/captainAscii.sock";
# Client:
print "begin\n";
my $socket = IO::Socket::UNIX->new(
	Type => SOCK_STREAM(),
	Peer => $SOCK_PATH,
) or die "failed to open socket $SOCK_PATH\n";
print "connected\n";

$| = 1;
my $ship_file = shift;

open (my $fh, '<', $ship_file) or die "failed to open $ship_file\n";

while(my $line = <$fh>){
	print $line;
	print $socket $line;
}
close ($fh);

print $socket "DONE\n";
select STDOUT;
print "loaded\n";

my $scr = new Term::Screen;
#$scr->clrscr();
$scr->noecho();

my $frame = 0;
my $lastFrame = 0;
my $playing = 1;

my $fps = 20;
my $framesInSec;
my $lastTime = time();
my $time = time();

my %bullets;

$socket->blocking(0);
while ($playing == 1){ 
	# message from server
	if (defined(my $in = <$socket>)){
	}
	# send keystrokes
	if ($scr->key_pressed()) { 
		my $chr = $scr->getch();
		print $socket "$chr\n";
	}
}
