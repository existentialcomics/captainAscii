#!/usr/bin/perl
#
use strict; use warnings;
use Term::ANSIColor 4.00 qw(RESET color :constants256);
require Term::Screen;
use List::MoreUtils qw(zip);
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
		      clock_gettime clock_getres clock_nanosleep clock time);
use Data::Dumper;
use SpaceShip;

use IO::Socket::UNIX;
my $SOCK_PATH = "$ENV{HOME}/captainAscii.sock";
unlink $SOCK_PATH;

my $server = IO::Socket::UNIX->new(
    Type => SOCK_STREAM(),
    Local => $SOCK_PATH,
    Listen => 1,
	Blocking => 0,
) or die "failed to open socket $SOCK_PATH";


#### wait for at least one client
my $conn = $server->accept();
# wait to recieve your first ship build
#
print "client connected\n";
my $waitShip = 1;
my $firstShip = "";
while ($waitShip){
	while(my $line = <$conn>){
			print "**$line\n";
		if ($line =~ /DONE/){
			print "done!\n";
			$waitShip = 0;
			last;
		} else {
			$firstShip .= $line;
		}
	}
}
print $firstShip . "\n";

my $ship = SpaceShip->new($firstShip, 5, 30, -1, 1);
$ship->{conn} = $conn;
my @ships = ($ship);

print "loaded\n";

### turn off blocking mode as we enter the main loop
$server->blocking(0);
$conn->blocking(0);

my $ship_file1 = shift;
my $ship_file2 = shift;

my @map;
my @lighting;

my $height = 40;
my $width = 150;

foreach my $x (0 .. $height){
	push @map, [];
	foreach my $y (0 .. $width){
		$map[$x][$y] = ' ';
		$lighting[$x][$y] = 0;
	}
}

my $starttime = time();
#           SpaceShip->new(file, x, y, facing, id, %options)
#my $ship2 = SpaceShip->new($firstShip, 3, 2, 1, 2);

# TODO push ship 2

my @players = ();

my $currentFacing = 0;

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

my %bullets;
my $shipIds = 3;
while ($playing == 1){ 
    if (defined( my $conntmp = $server->accept())){
		my $newShip = '';
		$waitShip = 1;

		while ($waitShip){
			while(my $line = <$conntmp>){
					print "**$line\n";
				if ($line =~ /DONE/){
					$waitShip = 0;
					last;
				} else {
					$newShip .= $line;
				}
			}
		}
		my $shipNew = SpaceShip->new($newShip, 5, 5, -1, $shipIds++);
		$conntmp->blocking(0);
		$shipNew->{conn} = $conntmp;
		push @ships, $shipNew;
	}

	$frame = int(time() * $fps);
	if ($frame == $lastFrame){ next; }

	$lastTime = $time;
	$time = time();

	$framesInSec++;
	$lastFrame = $frame;
	
	# reset map
	foreach my $x (0 .. $height){
		push @map, [];
		foreach my $y (0 .. $width){
			$map[$x][$y] = ' ';
			$lighting[$x][$y] = 0;
		}
	}

	foreach my $bulletK ( keys %bullets){
		my $bullet = $bullets{$bulletK};
		if ($bullet->{expires} < time()){
			delete $bullets{$bulletK};
			next;
		}
		$bullet->{x} += ($bullet->{dx} * ($time - $lastTime));
		$bullet->{y} += ($bullet->{dy} * ($time - $lastTime));
		$map[$bullet->{x}]->[$bullet->{y}] = $bullet->{'chr'};

		foreach my $ship (@ships){
			if ($ship->resolveCollision($bullet)){
				delete $bullets{$bulletK};	
			}
		}
		foreach my $ship (@ships){
			$ship->pruneParts();
		}
	}

	foreach my $ship (@ships){
		foreach my $part (@{ $ship->{'ship'} }){
			my $highlight = ((time() - $part->{'hit'} < .3) ? color('ON_RGB222') : '');
			my $bold = '';
			if (defined($part->{lastShot})){
				$bold = ((time() - $part->{'lastShot'} < .3) ? color('bold') : '');
			}
			my $px = $ship->{'y'} + $part->{'y'};
			my $py = $ship->{'x'} + $part->{'x'};
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
	foreach my $ship (@ships){
		my $conn = $ship->{conn};
		if (defined(my $in = <$conn>)){
			chomp($in);
			my $chr = $in;
			$ship->keypress($chr);
			print "chr: $chr\n";
		}
	}

	if ($scr->key_pressed()) { 
		my $chr = $scr->getch();
		foreach my $ship (@ships){
			$ship->keypress($chr);
		}
	}

	foreach my $ship (@ships){
		# power first because it disables move
		$ship->power($time - $lastTime);
		$ship->move($time - $lastTime);
		foreach (@{ $ship->shoot() }){
			$bullets{ rand(1000) . time() } = $_;
		}
	}

	### draw the screen
#	$scr->at(0, 0);
#	$scr->puts(
#		"weight: " .  $ship2->{weight} .
#		"  thrust: " . $ship2->{thrust} .
#		"  speed: " . sprintf('%.1f', $ship2->{speed}) . 
#		"  cost: \$" . $ship2->{cost} . 
#		"  powergen: " . sprintf('%.2f', $ship2->{currentPowerGen}) . "  "
#		);
#	# power
#	$scr->at(1, 0);
#	$scr->puts(sprintf('%-10s|', $ship2->{power} . ' / ' . int($ship2->{currentPower})). 
#	(color('ON_RGB' .
#		5 . 
#		(int(5 * ($ship2->{currentPower} / $ship2->{power}))) .
#		0) . " "
#		x ( 60 * ($ship2->{currentPower} / $ship2->{power})) . 
#		color('RESET') . " " x (60 - ( 60 * ($ship2->{currentPower} / $ship2->{power}))) ) . "|"
#	);
#	# display shield
#	if ($ship2->{shield} > 0){
#		$scr->at(2, 0);
#		$scr->puts(sprintf('%-10s|', $ship2->{shield} . ' / ' . int($ship2->{shieldHealth})). 
#		(color('ON_RGB' .
#			0 . 
#			(int(5 * ($ship2->{shieldHealth} / $ship2->{shield}))) .
#			5) . " "
#			x ( 60 * ($ship2->{shieldHealth} / $ship2->{shield})) . 
#			color('RESET') . " " x (60 - ( 60 * ($ship2->{shieldHealth} / $ship2->{shield}))) ) . "|"
#		);
#	}
	 
	#### display map ####
	foreach (0 .. $height){
		$scr->at($_ + 3, 0);
		my @lightingRow = map { color('ON_GREY' . $_) } @{ $lighting[$_] };
		$scr->puts(join "", zip( @lightingRow, @{ $map[$_] }));
	}
	#### ----------- ####
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
