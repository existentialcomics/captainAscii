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
use Storable;
use JSON::XS qw(encode_json decode_json);
my $SOCK_PATH = "/tmp/captainAscii.sock";
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

my $shipStr = "";

while(my $line = <$fh>){
	print $line;
	$shipStr .= $line;
	print $socket $line;
}
close ($fh);

print $socket "DONE\n";
select STDOUT;
print "loaded\n";

my $ship = SpaceShip->new($shipStr, 5, 5, -1, 'self');

my $scr = new Term::Screen;
$scr->clrscr();
$scr->noecho();

my $frame = 0;
my $lastFrame = 0;
my $playing = 1; 
my $fps = 20;
my $framesInSec;
my $lastTime = time();
my $time = time();

my $height = 40;
my $width = 100;

my @map;
my @lighting;
my %bullets;
my @ships;
push @ships, $ship;

$socket->blocking(0);
while ($playing == 1){ 
	my $cenX = int($width / 2);
	my $cenY = int($height / 2);
	#my $offx = $ship->{x} + $cenX;
	#my $offy = $ship->{y} + $cenY;
	my $offx = $cenX - $ship->{x} ;
	my $offy = $cenY - $ship->{y} ;

	# reset map
	foreach my $x (0 .. $height){
		push @map, [];
		foreach my $y (0 .. $width){
			my $modVal = abs(cos(int($x + $ship->{y}) * int($y + $ship->{x}) * 13));
			$map[$x][$y] = (($modVal < 0.03) ? ($modVal < 0.01 ? color("GREY1") : color("GREY5")) . '.' . color("RESET") : ' ');
			$lighting[$x][$y] = 0;
		}
	}

	# message from server
	#if (my $msg = Storable::thaw(<$socket>)){
	while (my $msgjson = <$socket>){
		my $msg = decode_json($msgjson);
		my $data = $msg->{d};
		if ($msg->{c} eq 'b'){
			my $key = $data->{k};
			$bullets{$key} = $data;
			$bullets{$key}->{expires} = time() + $data->{ex}; # set absolute expire time
		} elsif ($msg->{c} eq 's'){
			$ship->{x} = $data->{x};
			$ship->{y} = $data->{y};
			$ship->{powergen} = $data->{powergen};
			$ship->{currentPower} = $data->{currentPower};
		}
	}

	foreach my $bulletK ( keys %bullets){
		my $bullet = $bullets{$bulletK};
		my $spotX = $bullet->{x} + $offy;
		my $spotY = $bullet->{y} + $offx;
		if ($spotX > 0 && $spotY > 0){
			$map[$spotX]->[$spotY] = $bullet->{chr};
		}
	}

	# send keystrokes
	if ($scr->key_pressed()) { 
		my $chr = $scr->getch();
		print $socket "$chr\n";
	}

	foreach my $ship (@ships){
		foreach my $part (@{ $ship->{'ship'} }){
			my $highlight = ((time() - $part->{'hit'} < .3) ? color('ON_RGB222') : '');
			my $bold = '';
			if (defined($part->{lastShot})){
				$bold = ((time() - $part->{'lastShot'} < .3) ? color('bold') : '');
			}
			# TODO change to offx offy so it works for other ships
			my $px = $cenY + $part->{'y'};
			my $py = $cenX + $part->{'x'};
			$map[$px]->[$py] = $highlight . $bold . color('RGB033') . $part->{'part'}->{'chr'} . color('reset');
			if ($part->{'part'}->{'type'} eq 'shield'){
				if ($part->{'shieldHealth'} > 0){
					my $shieldLevel = ($highlight ne '' ? 5 : 2);
					if ($part->{'part'}->{'size'} eq 'medium'){
						$lighting[$px - 2]->[$py + $_] += $shieldLevel foreach (-1 .. 1);
						$lighting[$px - 1]->[$py + $_] += $shieldLevel foreach (-3 .. 3);
						$lighting[$px + 0]->[$py + $_] += $shieldLevel foreach (-4 .. 4);
						$lighting[$px + 1]->[$py + $_] += $shieldLevel foreach (-3 .. 3);
						$lighting[$px + 2]->[$py + $_] += $shieldLevel foreach (-1 .. 1);

					} elsif ($part->{'part'}->{'size'} eq 'large'){
						$lighting[$px - 3]->[$py + $_] += $shieldLevel foreach (-1 .. 1);
						$lighting[$px - 2]->[$py + $_] += $shieldLevel foreach (-3 .. 3);
						$lighting[$px - 1]->[$py + $_] += $shieldLevel foreach (-4 .. 4);
						$lighting[$px + 0]->[$py + $_] += $shieldLevel foreach (-5 .. 5);
						$lighting[$px + 1]->[$py + $_] += $shieldLevel foreach (-4 .. 4);
						$lighting[$px + 2]->[$py + $_] += $shieldLevel foreach (-3 .. 3);
						$lighting[$px + 3]->[$py + $_] += $shieldLevel foreach (-1 .. 1);
					}
				}
			}
		}
	}
	
	### draw the screen to Term::Screen
	foreach (0 .. $height){
		$scr->at($_ + 2, 0);
		my @lightingRow = map { color('ON_GREY' . $_) } @{ $lighting[$_] };
		$scr->puts(join "", zip( @lightingRow, @{ $map[$_] }));
	}

	#### ----- ship info ------ ####
	$scr->at($height + 5, 0);
	$scr->puts(
		"weight: " .  $ship->{weight} .
		"  thrust: " . $ship->{thrust} .
		"  speed: " . sprintf('%.1f', $ship->{speed}) . 
		"  cost: \$" . $ship->{cost} . 
		"  powergen: " . sprintf('%.2f', $ship->{currentPowerGen}) . "  "
		);
	# power
	$scr->at($height + 6, 0);
	$scr->puts(sprintf('%-10s|', $ship->{power} . ' / ' . int($ship->{currentPower})). 
	(color('ON_RGB' .
		5 . 
		(int(5 * ($ship->{currentPower} / $ship->{power}))) .
		0) . " "
		x ( 60 * ($ship->{currentPower} / $ship->{power})) . 
		color('RESET') . " " x (60 - ( 60 * ($ship->{currentPower} / $ship->{power}))) ) . "|"
	);
	# display shield
	if ($ship->{shield} > 0){
		$scr->at($height + 7, 0);
		$scr->puts(sprintf('%-10s|', $ship->{shield} . ' / ' . int($ship->{shieldHealth})). 
		(color('ON_RGB' .
			0 . 
			(int(5 * ($ship->{shieldHealth} / $ship->{shield}))) .
			5) . " "
			x ( 60 * ($ship->{shieldHealth} / $ship->{shield})) . 
			color('RESET') . " " x (60 - ( 60 * ($ship->{shieldHealth} / $ship->{shield}))) ) . "|"
		);
	}
}
