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
print "client connected\n";
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
	# listen for new ships
    if (defined( my $conntmp = $server->accept())){
		my $newShip = '';
		$waitShip = 1;

		while ($waitShip){
			while(my $line = <$conntmp>){
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
	
	# reset map - to be removed
	foreach my $x (0 .. $height){
		push @map, [];
		foreach my $y (0 .. $width){
			$map[$x][$y] = ' ';
			$lighting[$x][$y] = 0;
		}
	}

	### calcuate bullets
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

		# send the bullet data to clients
		foreach my $ship (@ships){
			sendMsg($ship->{conn}, 'b', 
				{
					x => $bullet->{x},
					y => $bullet->{y},
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
		foreach my $shipInner (@ships) {
			# send the inner loop ship the info of the outer loop ship
			my $msg = {};
			if ($ship->{id} eq $shipInner->{id}){
				$msg = {
					id => 'self' ,
					x => $ship->{x},
					y => $ship->{y},
					shieldHealth => $ship->{shieldHealth},
					currentPower => $ship->{currentPower},
					powergen     => $ship->{powergen},
				};
			} else {
				# we only need to know location
			}
			sendMsg($shipInner->{conn}, 's', $msg);
		}
	}

	# recieve ship input
	foreach my $ship (@ships){
		if (defined(my $in = <$conn>)){
			chomp($in);
			my $chr = $in;
			$ship->keypress($chr);
			#print "chr: $chr\n";
		}
	}

	# server input, replace with stdin
	if ($scr->key_pressed()) { 
		my $chr = $scr->getch();
		foreach my $ship (@ships){
			$ship->keypress($chr);
		}
	}

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
	foreach (0 .. $height){
		$scr->at($_ + 3, 0);
		my @lightingRow = map { color('ON_GREY' . $_) } @{ $lighting[$_] };
		$scr->puts(join "", zip( @lightingRow, @{ $map[$_] }));
	}
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
