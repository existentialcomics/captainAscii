#!/usr/bin/perl
#
use POSIX;
use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname(abs_path($0));

use CaptainAscii::Server;
use strict;
use warnings;

my $cost   = shift;
my $socket = shift;
$socket = (defined($socket) ? $socket : '/tmp/captainAscii.sock');

my $options = {};
if ($cost){
	$options->{maxInitialCost} = $cost;
}

if (-e $socket){
	unlink $socket;
}

$SIG{PIPE} = 'IGNORE';
#$SIG{PIPE} = \&catchSigPipe;
#sub catchSigPipe {
	#print "sig pipe error!\n";
#}

my $server = CaptainAscii::Server->new($socket, $options);

$server->loop();
