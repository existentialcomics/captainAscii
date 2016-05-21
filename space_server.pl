#!/usr/bin/perl
#
use strict; use warnings;
use Term::ANSIColor 4.00 qw(RESET color :constants256);
require Term::Screen;
use List::MoreUtils qw(zip);
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
		      clock_gettime clock_getres clock_nanosleep clock time);
use SpaceShip;
use Storable;
use Data::Dumper;
use JSON::XS qw(encode_json decode_json);

use IO::Socket::UNIX;
my $SOCK_PATH = "/tmp/captainAscii.sock";
unlink $SOCK_PATH;

my $server = IO::Socket::UNIX->new(
    Type => SOCK_STREAM(),
    Local => $SOCK_PATH,
    Listen => 1,
	Blocking => 0,
) or die "failed to open socket $SOCK_PATH";

chmod 0777, $SOCK_PATH;

#### wait for at least one client
my $conn = $server->accept();
# wait to recieve your first ship build
#
print "first client connected\n";
my $waitShip = 1;
my $firstShip = "";
while ($waitShip){
	while(my $line = <$conn>){
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

# TODO push ship 2

my @players = ();

my $currentFacing = 0;

#my $scr = new Term::Screen;
#$scr->clrscr();
#$scr->noecho();
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
	# listen for new ships
    if (defined( my $conntmp = $server->accept())){
		my $newShipDesign = '';
		$waitShip = 1;
		print "new ship entering...\n";
		while ($waitShip){
			while(my $line = <$conntmp>){
				if ($line =~ /DONE/){
					$waitShip = 0;
					last;
				} else {
					$newShipDesign .= $line;
				}
			}
		}
		print "$newShipDesign\n";
		my $shipNew = SpaceShip->new($newShipDesign, 5, 5, -1, $shipIds++);
		foreach my $ship (@ships){
			sendMsg($ship->{conn}, 'newship', {
				design => $newShipDesign,
				x => 5,
				y => 5,
				id => $shipNew->{id},
			});
		}
		$conntmp->blocking(0);
		$shipNew->{conn} = $conntmp;
		push @ships, $shipNew;
		print "player loaded, " . ($#ships + 1) . " in game.\n";
	}

	$frame = int(time() * $fps);
	if ($frame == $lastFrame){ next; }

	$lastTime = $time;
	$time = time();

	$framesInSec++;
	$lastFrame = $frame;

	### calcuate bullets
	foreach my $bulletK ( keys %bullets){
		my $bullet = $bullets{$bulletK};
		if ($bullet->{expires} < time()){
			delete $bullets{$bulletK};
			next;
		}
		$bullet->{x} += ($bullet->{dx} * ($time - $lastTime));
		$bullet->{y} += ($bullet->{dy} * ($time - $lastTime));
		#$map[$bullet->{x}]->[$bullet->{y}] = $bullet->{'chr'};

		foreach my $ship (@ships){
			if ($ship->resolveCollision($bullet)){
				# TODO send bullet del to clients
				delete $bullets{$bulletK};	
			}
		}

		# send the bullet data to clients
		foreach my $ship (@ships){
			sendMsg($ship->{conn}, 'b', 
				{
					x => $bullet->{x},
					y => $bullet->{y},
					dx => $bullet->{dx},
					dy => $bullet->{dy},
					k => $bulletK,
					ex => ( $bullet->{expires} - time() ), # time left in case client clock differs
					chr => $bullet->{chr}
				}
			);
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
		}
	}
	foreach my $ship (@ships){
		foreach my $shipInner (@ships) {
			# send the inner loop ship the info of the outer loop ship
			my $msg = {};
			if ($ship->{id} eq $shipInner->{id}){
				$msg = {
					id => 'self' ,
					x => $ship->{x},
					y => $ship->{y},
					dx => $ship->{movingHoz},
					dy => $ship->{movingVert},
					shieldHealth => $ship->{shieldHealth},
					currentPower => $ship->{currentPower},
					powergen     => $ship->{powergen},
				};
				sendMsg($shipInner->{conn}, 's', $msg);
			} else {
				$msg = {
					id => $ship->{id} ,
					x => $ship->{x},
					y => $ship->{y},
					dx => $ship->{movingHoz},
					dy => $ship->{movingVert},
					shieldHealth => $ship->{shieldHealth},
					currentPower => $ship->{currentPower},
					powergen     => $ship->{powergen},
				};
				sendMsg($shipInner->{conn}, 's', $msg);
				# we only need to know location
			}
		}
	}

	# recieve ship input
	foreach my $ship (@ships){
		my $socket = $ship->{conn};
		if (defined(my $in = <$socket>)){
			chomp($in);
			my $chr = $in;
			$ship->keypress($chr);
			#print "chr: $chr\n";
		}
	}

	# server input, replace with stdin
	#if ($scr->key_pressed()) { 
		#my $chr = $scr->getch();
		#foreach my $ship (@ships){
			#$ship->keypress($chr);
		#}
	#}

	# calculate power and movement
	foreach my $ship (@ships){
		# power first because it disables move
		$ship->power($time - $lastTime);
		$ship->move($time - $lastTime);
		foreach (@{ $ship->shoot() }){
			$bullets{ rand(1000) . time() } = $_;
		}
	}

	#### display map - to be removed ####
#	foreach (0 .. $height){
#		$scr->at($_ + 3, 0);
#		my @lightingRow = map { color('ON_GREY' . $_) } @{ $lighting[$_] };
#		$scr->puts(join "", zip( @lightingRow, @{ $map[$_] }));
#	}
} ### END LOOP

### transmit a msg to the clients
sub sendMsg {
	my ($socket, $category, $data) = @_;
	my $msg = {
		c => $category,
		d => $data
	};
	print $socket (JSON::XS::encode_json($msg)) . "\n";
}
