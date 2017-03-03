#!/usr/bin/perl
#
use SpaceClient;

my $ship = shift;
my $socket = '/tmp/captainAscii.sock';
my $color = shift;

my @allowedColors = qw(red  green  yellow  blue  magenta  cyan  white);

$SIG{__DIE__} = \&log_die;
$SIG{__WARN__} = \&log_warn;

sub log_die
{
    write_log(@_);
    die @_;
}

sub log_warn
{
    write_log(@_);
}

sub write_log
{
    open LOG,">>",'error-warn.log';
    print LOG @_,"\n";
    close LOG;
}

if (!$ship){
	print "enter ship file\n";
	exit;
}

if ($color){
	if (! grep { $_ eq $color } @allowedColors){
		print "color $color not allowed\n";
		print "allowed colors: " . (join ", ", @allowedColors) . "\n";
		exit;
	}
}

if (! -f $ship){
	print "ship file $ship not a file\n";
	exit;
}

my $client = SpaceClient->new($ship, $socket, $color);


