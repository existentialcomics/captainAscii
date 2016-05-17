#!/usr/bin/perl
#
use strict; use warnings;
use Tie::File;
use Term::ANSIColor 4.00 qw(RESET color :constants256);
use Fcntl 'O_RDONLY';
require Term::Screen;
use List::MoreUtils qw(zip);
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
		      clock_gettime clock_getres clock_nanosleep clock time);
use Data::Dumper;
use SpaceShip;

my $ship_file1 = shift;
my $ship_file2 = shift;
open (my $fh1, "<", $ship_file1) or die "failed to open $ship_file1\n";
my $ship_str1 = "";
while (<$fh1>){
	$ship_str1 .= $_;
}
close $fh1;

open (my $fh2, "<", $ship_file2) or die "failed to open $ship_file2\n";
my $ship_str2 = "";
while (<$fh2>){
	$ship_str2 .= $_;
}
close $fh2;

#           SpaceShip->new(file, x, y, facing, id, %options)
my $ship  = SpaceShip->new($ship_str1, 5, 30, -1, 1, {controls => 'b'});
my $ship2 = SpaceShip->new($ship_str2, 3, 2, 1, 2);

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

my $scr = new Term::Screen;

my $starttime = time();

my @ships = ($ship, $ship2);

my @players = ();

my $currentFacing = 0;

$scr->clrscr();
$scr->noecho();
my $frame = 0;
my $lastFrame = 0;
my $playing = 1;

my $fps = 20;
my $framesInSec;
my $lastTime = time();
my $time = time();

my $bulletSpeed = 5.0;
my %bullets;

while ($playing == 1){ 
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
		$bullet->{x} += ($bullet->{dx} * ($time - $lastTime));
		$bullet->{y} += ($bullet->{dy} * ($time - $lastTime));
		if ($bullet->{x} < 0 || $bullet->{x} > $height) { delete $bullets{$bulletK}; next; }
		if ($bullet->{y} < 0 || $bullet->{y} > $width){ delete $bullets{$bulletK}; next; }
		$map[$bullet->{x}]->[$bullet->{y}] = $bullet->{'chr'};

		if ($ship->resolveCollision($bullet)){
			delete $bullets{$bulletK};	
		}
		if ($ship2->resolveCollision($bullet)){
			delete $bullets{$bulletK};	
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
	$scr->at(0, 0);
	$scr->puts(
		"weight: " .  $ship2->{weight} .
		"  thrust: " . $ship2->{thrust} .
		"  speed: " . sprintf('%.1f', $ship2->{speed}) . 
		"  cost: \$" . $ship2->{cost} . 
		"  powergen: " . sprintf('%.2f', $ship2->{currentPowerGen}) . "  "
		);
	# power
	$scr->at(1, 0);
	$scr->puts(sprintf('%-10s|', $ship2->{power} . ' / ' . int($ship2->{currentPower})). 
	(color('ON_RGB' .
		5 . 
		(int(5 * ($ship2->{currentPower} / $ship2->{power}))) .
		0) . " "
		x ( 60 * ($ship2->{currentPower} / $ship2->{power})) . 
		color('RESET') . " " x (60 - ( 60 * ($ship2->{currentPower} / $ship2->{power}))) ) . "|"
	);
	# display shield
	if ($ship2->{shield} > 0){
		$scr->at(2, 0);
		$scr->puts(sprintf('%-10s|', $ship2->{shield} . ' / ' . int($ship2->{shieldHealth})). 
		(color('ON_RGB' .
			0 . 
			(int(5 * ($ship2->{shieldHealth} / $ship2->{shield}))) .
			5) . " "
			x ( 60 * ($ship2->{shieldHealth} / $ship2->{shield})) . 
			color('RESET') . " " x (60 - ( 60 * ($ship2->{shieldHealth} / $ship2->{shield}))) ) . "|"
		);
	}
	 
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
