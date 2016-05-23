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
if (! -e $SOCK_PATH){
	system('perl space_server.pl');
}
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

my $height = 55;
my $width = 130;

my %lighting;
my @map;
#my @lighting;
my %bullets;
my @ships;
my %ships;
push @ships, $ship;
$ships{$ship->{id}} = $ship;

my $debug = "";
$socket->blocking(0);
while ($playing == 1){ 
	### message from server
	while (my $msgjson = <$socket>){
		my $msg = decode_json($msgjson);
		my $data = $msg->{d};
		if ($msg->{c} eq 'b'){ # bullet msg
			my $key = $data->{k};
			# new bullet
			if (!defined($bullets{$key})){
				#$ships{$data->{sid}}->{ship}->[$data->{pid}]->{'hit'} = time();
				#$ships{'self'}->{parts}->{$data->{pid}}->{'hit'} = time();
				if (defined($ships{$data->{sid}})){
					my $part = $ships{$data->{sid}}->getPartById($data->{pid});
					$part->{'lastShot'} = time();
				} else {
					$debug = "ship not found $data->{sid}";
				}
			}
			$bullets{$key} = $data;
			$bullets{$key}->{expires} = time() + $data->{ex}; # set absolute expire time
		} elsif ($msg->{c} eq 's'){
			foreach my $ship (@ships){
				next if ($ship->{id} ne $data->{id});
				$ship->{x} = $data->{x};
				$ship->{y} = $data->{y};
				$ship->{movingVert} = $data->{dy},
				$ship->{movingHoz} = $data->{dx},
				$ship->{powergen} = $data->{powergen};
				$ship->{direction} = $data->{direction};
				$ship->{currentPower} = $data->{currentPower};
			}
		} elsif ($msg->{c} eq 'newship'){
			my $shipNew = SpaceShip->new($data->{design}, $data->{x}, $data->{y}, -1, $data->{id});
			$ships{$shipNew->{id}} = $shipNew;
			push @ships, $shipNew;
		} elsif ($msg->{c} eq 'dam'){
			#$debug = $data->{bullet_del} . " - " . exists($bullets{$data->{bullet_del}});
			delete $bullets{$data->{bullet_del}};
			foreach my $s (@ships){
				if ($s->{id} eq $data->{ship_id}){
					if (defined($data->{shield})){
						$s->damageShield($data->{id}, $data->{shield});
					}
					if (defined($data->{health})){
						$s->damagePart($data->{id}, $data->{health});
					}
				}
			}
		} elsif ($msg->{c} eq 'shipchange'){
			foreach my $s (@ships){
				if ($s->{id} eq $data->{'ship_id'}){
					$s->_loadShipByMap($data->{'map'});
				}
			}
		} elsif ($msg->{c} eq 'setShipId'){
			foreach my $s (@ships){
				if ($s->{id} eq $data->{'old_id'}){
					$s->{id} = $data->{'new_id'};
					$debug = "$data->{'old_id'} to $data->{'new_id'}";
				}
			}
		}
	}

	my $cenX = int($width / 2);
	my $cenY = int($height / 2);
	#my $offx = $ship->{x} + $cenX;
	#my $offy = $ship->{y} + $cenY;
	my $offx = $cenX - int($ship->{x});
	my $offy = $cenY - int($ship->{y});

	%lighting = ();
	# reset map
	foreach my $x (0 .. $height){
		push @map, [];
		foreach my $y (0 .. $width){
			my $modVal = abs(cos(int($x + $ship->{y}) * int($y + $ship->{x}) * 53 ));
			my $chr = '.';
			my $col = "";
			if ($modVal < 0.03){
				if ($modVal < 0.0015){
					$col = color("ON_GREY1");
					$chr = '*';
				} elsif ($modVal < 0.0030){
					$col = color("GREY" . int(rand(22)));
				} elsif ($modVal < 0.0045){
					$col = color("yellow");
				} elsif ($modVal < 0.02){
					$col = color("GREY2");
				} else {
					$col = color("GREY5");
				}
			}
			if ($ship->{movingVert} && $ship->{movingHoz}){
				# TODO moving upleft = \, or /
			} elsif ($ship->{movingVert}){
				$chr = '|';
			} elsif ($ship->{movingHoz}){
				$chr = '–';
			}

			$map[$x][$y] = (($modVal < 0.03) ? $col . $chr . color("RESET") : ' ');
			#$lighting[$x][$y] = 0;
		}
	}

	foreach my $bulletK ( keys %bullets){
		my $bullet = $bullets{$bulletK};
		if ($bullet->{expires} < time()){
			delete $bullets{$bulletK};
			next;
		}
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
		foreach my $part ($ship->getParts()){
			my $highlight = ((time() - $part->{'hit'} < .3) ? color('ON_RGB222') : '');
			my $bold = '';
			if (defined($part->{lastShot})){
				$bold = ((time() - $part->{'lastShot'} < .3) ? color('bold') : '');
			}
			my $px = ($offy + int($ship->{y})) + $part->{'y'};
			my $py = ($offx + int($ship->{x})) + $part->{'x'};
			if (! defined ($part->{x})){ $debug = Dumper($part); next; }
			setMap($px, $py, $highlight . $bold . $ship->{color} . $part->{'chr'} . color('reset'));
			if ($part->{'part'}->{'type'} eq 'shield'){
				if ($part->{'shieldHealth'} > 0){
					my $shieldLevel = ($highlight ne '' ? 5 : 2);
					if ($part->{'part'}->{'size'} eq 'medium'){
						addLighting($px - 2, $py + $_, $shieldLevel) foreach (-1 .. 1);
						addLighting($px - 1, $py + $_, $shieldLevel) foreach (-3 .. 3);
						addLighting($px + 0, $py + $_, $shieldLevel) foreach (-4 .. 4);
						addLighting($px + 1, $py + $_, $shieldLevel) foreach (-3 .. 3);
						addLighting($px + 2, $py + $_, $shieldLevel) foreach (-1 .. 1);
					} elsif ($part->{'part'}->{'size'} eq 'large'){
						addLighting($px - 3, $py + $_, $shieldLevel) foreach (-1 .. 1);
						addLighting($px - 2, $py + $_, $shieldLevel) foreach (-3 .. 3);
						addLighting($px - 1, $py + $_, $shieldLevel) foreach (-4 .. 4);
						addLighting($px + 0, $py + $_, $shieldLevel) foreach (-5 .. 5);
						addLighting($px + 1, $py + $_, $shieldLevel) foreach (-4 .. 4);
						addLighting($px + 2, $py + $_, $shieldLevel) foreach (-3 .. 3);
						addLighting($px + 3, $py + $_, $shieldLevel) foreach (-1 .. 1);
					}
				}
			}
		}
		my ($aimx, $aimy) = $ship->getAimingCursor();
		my $px = ($offy + int($ship->{y})) + $aimx;
		my $py = ($offx + int($ship->{x})) + $aimy;
		setMap($px, $py, color('GREEN') . "+");
	}
	
	### draw the screen to Term::Screen
	foreach my $i (0 .. $height){
		$scr->at($i + 1, 0);
		my $row = '';
		foreach my $j (0 .. $width){
			$row .= (defined($lighting{$i}->{$j}) ? color('ON_GREY' . $lighting{$i}->{$j}) : color('ON_BLACK'));
			$row .= (defined($map[$i]->[$j]) ? $map[$i]->[$j] : " ");
		}
		#$scr->puts(join "", zip( @lightingRow, @{ $map[$_] }));
		$scr->puts($row);
	}

	#### ----- ship info ------ ####
	$scr->at($height + 2, 0);
	#$scr->puts("ships in game: " . ($#ships + 1) . " aim: " . $ship->getQuadrant());
	$scr->puts(sprintf('dir: %.2f  quad: %s   ', $ship->{direction}, $ship->getQuadrant()) );
	$scr->at($height + 3, 0);
	$scr->puts(
		"weight: " .  $ship->{weight} .
		"  thrust: " . $ship->{thrust} .
		"  speed: " . sprintf('%.1f', $ship->{speed}) . 
		"  cost: \$" . $ship->{cost} . 
		"  powergen: " . sprintf('%.2f', $ship->{currentPowerGen}) . "  "
		);
	# power
	$scr->at($height + 4, 0);
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
		$scr->at($height + 5, 0);
		$scr->puts(sprintf('%-10s|', $ship->{shield} . ' / ' . int($ship->{shieldHealth})). 
		(color('ON_RGB' .
			0 . 
			(int(5 * ($ship->{shieldHealth} / $ship->{shield}))) .
			5) . " "
			x ( 60 * ($ship->{shieldHealth} / $ship->{shield})) . 
			color('RESET') . " " x (60 - ( 60 * ($ship->{shieldHealth} / $ship->{shield}))) ) . "|"
		);
	}
	$scr->at($height + 6, 0);
	$scr->puts($debug);
}

sub setMap {
	my ($x, $y, $chr) = @_;
	if ( ! onMap($x, $y) ){ return 0; }
	$map[$x]->[$y] = $chr;
}

sub addLighting {
	my ($x, $y, $level) = @_;
	if ( ! onMap($x, $y) ){ return 0; }
	$lighting{$x}->{$y} += $level;
}

sub onMap {
	my ($x, $y) = @_;
	return ($x > 0 && $y > 0 && $x < $height && $y < $width);
}
