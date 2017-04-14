use strict; use warnings;
package CaptainAscii::Client;

BEGIN {
	$Curses::OldCurses = 1;
	#$Curses::UI::utf8 = 1;
}
use Term::ANSIColor 4.00 qw(RESET color :constants256 colorstrip);
require Term::Screen;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep time);
use Data::Dumper;
use JSON::XS qw(encode_json decode_json);
use IO::Socket::UNIX;
use Math::Trig ':radial';
use Text::Wrap;
use Curses;
use POSIX qw(floor ceil);

use CaptainAscii::Ship;

use constant {
	ASPECTRATIO => 0.66666666,
	PI => 3.1415
};

my %colors = ();
my %cursesColors = ();
my $starMapSize = 0;
my @starMap;
my @starMapStr;
my @lighting;
my $lastFrame = time();
my %lights = ();
my $lightsKey = 1;

my $useCurses = 1;
my $cursesColorCount = 1;

my %colorCodes = (
    BOLD    => 1,
    BLACK   => 0,
    RED     => 1,
    GREEN   => 2,
    YELLOW  => 3,
    BLUE    => 4,
    MAGENTA => 5,
    CYAN    => 6,
    WHITE   => 7,
    ON_BLACK   => 0,
    ON_RED     => 1,
    ON_GREEN   => 2,
    ON_YELLOW  => 3,
    ON_BLUE    => 4,
    ON_MAGENTA => 5,
    ON_CYAN    => 6,
    ON_WHITE   => 7,
    DARKGREY     => 8,
    LIGHTRED     => 9,
    LIGHTGREEN   => 10,
    LIGHTYELLOW  => 11,
    LIGHTBLUE    => 12,
    LIGHTMAGENTA => 13,
    LIGHTCYAN    => 14,
    LIGHTWHITE   => 15,
    ON_DARKGREY     => 8,
    ON_LIGHTRED     => 9,
    ON_LIGHTGREEN   => 10,
    ON_LIGHTYELLOW  => 11,
    ON_LIGHTBLUE    => 12,
    ON_LIGHTMAGENTA => 13,
    ON_LIGHTCYAN    => 14,
    ON_LIGHTWHITE   => 15,
);

# The first 16 256-color codes are duplicates of the 16 ANSI colors,
# included for completeness.
foreach (0 .. 15){
    $colorCodes{"ANSI$_"} = $_;
    $colorCodes{"ON_ANSI$_"} = $_;
}

# 256-color RGB colors.  Red, green, and blue can each be values 0 through 5,
# and the resulting 216 colors start with color 16.
for my $r (0 .. 5) {
    for my $g (0 .. 5) {
        for my $b (0 .. 5) {
            my $code = 16 + (6 * 6 * $r) + (6 * $g) + $b;
            $colorCodes{"RGB$r$g$b"}    = $code;
            $colorCodes{"ON_RGB$r$g$b"} = $code;
        }
    }
}

# The last 256-color codes are 24 shades of grey.
for my $n (0 .. 23) {
    my $code = $n + 232;
    $colorCodes{"GREY$n"}    = $code;
    $colorCodes{"ON_GREY$n"} = $code;
}

sub new {
	my $class = shift;

	my $self = {};
	bless( $self, $class );

	if ($self->_init(@_)){
		return $self;
	} else {
		return undef;
	}
}

sub _init {
	my $self = shift;
	my $ship_file = shift;
	my $socket = shift;
	my $color = shift;

	$self->{msg} = '';
	$self->{msgs} = ();
	$self->{chatWidth} = 80;
	$self->{chatOffset} = 0;

	$self->{zoom} = 1;
	$self->resizeScr();

    ### curses init
    initscr();
    curs_set(0);
	start_color();
    attrset(COLOR_PAIR(0));
	noecho();
    #my $res = $self->{_curses_info}      = newwin($self->{height}, 0, 10, 40);
	# *newwin(int nlines, int ncols, int begin_y, int begin_x);
    my $resI= $self->{_curses_info} = newwin($self->{termHeight} - $self->{height} - 1, $self->{termWidth} -1 , $self->{height}, 0);
    my $resS = $self->{_curses_side} = newwin($self->{height}, $self->{termWidth} - $self->{width} , 0, $self->{width});

	$self->_generateStarMap();

	$self->{lastFrame} = time();
	$self->{lastInfoPrint} = time();

	$self->{username} = getpwuid($<);

	$self->{debug} = "";
	$self->{maxFps} = 40;
	$self->{maxBackgroundFps} = 6;
	$self->{maxInfoFps} = 6;
	$self->{fps} = 40;
	$self->{mode} = 'drive';

	$self->{cursorx} = 0;
	$self->{cursory} = 0;

	open (my $fh, '<', $ship_file) or die "failed to open $ship_file\n";

	my $shipStr = "";

	# TODO don't send the ship until it successfully loads locally
	while(my $line = <$fh>){
		$shipStr .= $line;
	}
	close ($fh);

	#$shipStr = $self->designShip($shipStr);
	#print "socket: $socket \n";
	
	$self->_bindSocket($socket);
	$self->_loadShip($shipStr, $color);

	$self->{socket}->blocking(0);

	$self->{bullets} = {};
	$self->{items}   = {};

	$self->loop();

	return 1;
}

sub _generateStarMap {
	my $self = shift;
	my $size = shift;
	if (!defined($size)){ $size = 300; }

	print "loading maps...\n";

	$starMapSize = $size;
    #$self->{_curses_map}      = newpad($self->{height}, $self->{width});
    $self->{_curses_map} = newpad($size * 2, $size * 2);
    $self->{_curses_mapBlank} = newpad($size * 2, $size * 2);
    $self->{_curses_mapBlankNS} = newpad($size * 2, $size * 2);
    $self->{_curses_mapBlankNS2} = newpad($size * 2, $size * 2);
    $self->{_curses_mapBlankNS3} = newpad($size * 2, $size * 2);
    $self->{_curses_mapBlankNS4} = newpad($size * 2, $size * 2);
    $self->{_curses_mapBlankEW} = newpad($size * 2, $size * 2);
    $self->{_curses_mapBlankEW2} = newpad($size * 2, $size * 2);
    $self->{_curses_mapBlankEW3} = newpad($size * 2, $size * 2);
    $self->{_curses_mapBlankEW4} = newpad($size * 2, $size * 2);
    $self->{_curses_mapBlankNeSw} = newpad($size * 2, $size * 2);
    $self->{_curses_mapBlankNeSw2} = newpad($size * 2, $size * 2);
    $self->{_curses_mapBlankNeSw3} = newpad($size * 2, $size * 2);
    $self->{_curses_mapBlankNeSw4} = newpad($size * 2, $size * 2);
    $self->{_curses_mapBlankNwSe} = newpad($size * 2, $size * 2);
    $self->{_curses_mapBlankNwSe2} = newpad($size * 2, $size * 2);
    $self->{_curses_mapBlankNwSe3} = newpad($size * 2, $size * 2);
    $self->{_curses_mapBlankNwSe4} = newpad($size * 2, $size * 2);
    $self->{_curses_mapBlankNwSe5} = newpad($size * 2, $size * 2);
	foreach my $x (0 .. $size){
		push @starMap, [ (' ') x $size ];
		push @starMapStr, '';
		foreach my $y (0 .. $size){
			my $rand = rand();
			if ($rand > 0.03){
				$starMapStr[$x] .= ' ';
                next;
			}
			my $starRand = rand();
			my $chr = '.';
			my $col = "";
            my $fore = 'GREY4';
            my $back = 'ON_BLACK';
			if ($starRand < 0.02){
				$chr = '*';
				if ($starRand < 0.002){
                    $fore = 'YELLOW';
				} elsif ($starRand < 0.012){
				    $fore = "GREY" . int(rand(22));
                }
			} elsif ($starRand < 0.5){
				$fore = "GREY" . int(rand(22));
			} elsif ($starRand < 0.10){
                $fore = 'YELLOW';
			} elsif ($starRand < 0.30){
                $fore = 'GREY2';
			}
            $col = getColor($fore, $back);
			$starMap[$x]->[$y] = $col . $chr;
			$starMapStr[$x] .= $chr;
			putCursesChr($self->{_curses_mapBlank}, $x, $y, $chr, $fore, 'ON_BLACK');
			putCursesChr($self->{_curses_mapBlank}, $x + $size, $y + $size, $chr, $fore, 'ON_BLACK');
			putCursesChr($self->{_curses_mapBlank}, $x, $y + $size, $chr, $fore, 'ON_BLACK');
			putCursesChr($self->{_curses_mapBlank}, $x + $size, $y, $chr, $fore, 'ON_BLACK');

			putCursesChr($self->{_curses_mapBlankNS}, $x, $y, '│', $fore, 'ON_BLACK');
			putCursesChr($self->{_curses_mapBlankNS}, $x + $size, $y + $size, '│', $fore, 'ON_BLACK');
			putCursesChr($self->{_curses_mapBlankNS}, $x, $y + $size, '│', $fore, 'ON_BLACK');
			putCursesChr($self->{_curses_mapBlankNS}, $x + $size, $y, '│', $fore, 'ON_BLACK');

			putCursesChr($self->{_curses_mapBlankEW}, $x, $y, '─', $fore, 'ON_BLACK');
			putCursesChr($self->{_curses_mapBlankEW}, $x + $size, $y + $size, '─', $fore, 'ON_BLACK');
			putCursesChr($self->{_curses_mapBlankEW}, $x, $y + $size, '─', $fore, 'ON_BLACK');
			putCursesChr($self->{_curses_mapBlankEW}, $x + $size, $y, '─', $fore, 'ON_BLACK');

            for my $i (-1 .. 1){
                putCursesChr($self->{_curses_mapBlankNS2}, $x + $i, $y, '│', $fore, 'ON_BLACK');
                putCursesChr($self->{_curses_mapBlankNS2}, $x + $i + $size, $y + $size, '│', $fore, 'ON_BLACK');
                putCursesChr($self->{_curses_mapBlankNS2}, $x + $i, $y + $size, '│', $fore, 'ON_BLACK');
                putCursesChr($self->{_curses_mapBlankNS2}, $x + $i + $size, $y, '│', $fore, 'ON_BLACK');
           
                putCursesChr($self->{_curses_mapBlankEW2}, $x, $y + $i, '─', $fore, 'ON_BLACK');
                putCursesChr($self->{_curses_mapBlankEW2}, $x + $size, $y + $i + $size, '─', $fore, 'ON_BLACK');
                putCursesChr($self->{_curses_mapBlankEW2}, $x, $y + $i + $size, '─', $fore, 'ON_BLACK');
                putCursesChr($self->{_curses_mapBlankEW2}, $x + $size, $y + $i, '─', $fore, 'ON_BLACK');
            }
            for my $i (-3 .. 3){
                putCursesChr($self->{_curses_mapBlankNS3}, $x + $i, $y, '│', $fore, 'ON_BLACK');
                putCursesChr($self->{_curses_mapBlankNS3}, $x + $i + $size, $y + $size, '│', $fore, 'ON_BLACK');
                putCursesChr($self->{_curses_mapBlankNS3}, $x + $i, $y + $size, '│', $fore, 'ON_BLACK');
                putCursesChr($self->{_curses_mapBlankNS3}, $x + $i + $size, $y, '│', $fore, 'ON_BLACK');
           
                putCursesChr($self->{_curses_mapBlankEW3}, $x, $y + $i, '─', $fore, 'ON_BLACK');
                putCursesChr($self->{_curses_mapBlankEW3}, $x + $size, $y + $i + $size, '─', $fore, 'ON_BLACK');
                putCursesChr($self->{_curses_mapBlankEW3}, $x, $y + $i + $size, '─', $fore, 'ON_BLACK');
                putCursesChr($self->{_curses_mapBlankEW3}, $x + $size, $y + $i, '─', $fore, 'ON_BLACK');
            }
            for my $i (-4 .. 4){
                putCursesChr($self->{_curses_mapBlankNS3}, $x + $i, $y, '│', $fore, 'ON_BLACK');
                putCursesChr($self->{_curses_mapBlankNS3}, $x + $i + $size, $y + $size, '│', $fore, 'ON_BLACK');
                putCursesChr($self->{_curses_mapBlankNS3}, $x + $i, $y + $size, '│', $fore, 'ON_BLACK');
                putCursesChr($self->{_curses_mapBlankNS3}, $x + $i + $size, $y, '│', $fore, 'ON_BLACK');
           
                putCursesChr($self->{_curses_mapBlankEW3}, $x, $y + $i, '─', $fore, 'ON_BLACK');
                putCursesChr($self->{_curses_mapBlankEW3}, $x + $size, $y + $i + $size, '─', $fore, 'ON_BLACK');
                putCursesChr($self->{_curses_mapBlankEW3}, $x, $y + $i + $size, '─', $fore, 'ON_BLACK');
                putCursesChr($self->{_curses_mapBlankEW3}, $x + $size, $y + $i, '─', $fore, 'ON_BLACK');
            }
		}
	}
}

sub sprite {
	my $array = shift;
	if (ref($array) ne 'ARRAY'){ return $array; }
	my $length = time() - $lastFrame;
	if ($length > 1){ $length = 1 }
	if ($length < 0){ $length = 0 }
	my $chr = $array->[$length * @{$array}];
	if (!$chr){ $chr = $array->[0] }
	return $chr;
}

sub designShip {
	my $self = shift;
	my $inputDesign = shift;
	my $cash = 1500;
	my $scr = new Term::Screen;

	my $ship = new CaptainAscii::Ship($inputDesign, 0, 0, 1);
	$self->{ship} = $ship;
	my @shipArr = @{ $ship->getDisplayArray(5, 5) };

	$scr->clrscr();
	$scr->noecho();
	my $designing = 1;
	my $shipDesign = $inputDesign;
	my $x = 15;
	my $y = 30;
	my @ship;
	foreach my $x (0 .. 30){
		foreach my $y (0 .. 60){
			$ship[$x][$y] = (defined($shipArr[$y][$x]) ? $shipArr[$y][$x] : ' ');
		}
	}

	while ($designing == 1){
		my $px = 0;
		$self->printInfo();
		for my $row (@ship){
			$px++;
			my $rowPrint = join "", @{$row};
			$self->putStr(
                $px, 0,
                getColor('WHITE', 'ON_GREY3') . $rowPrint . getColor('WHITE', 'ON_BLACK')
            );
		}
		my $chr = undef;
		while (!defined($chr)){
			if ($scr->key_pressed()) { 
				$chr = $scr->getch();
				if ($chr eq 'a'){ $y--; }
				elsif ($chr eq 'd'){ $y++; }
				elsif ($chr eq 's'){ $x++; }
				elsif ($chr eq 'w'){ $x--; }
				elsif (defined($ship->getPartDef($chr))){
					$ship[$x - 1][$y] = $chr;	
				} elsif ($chr eq ' '){
					$ship[$x - 1][$y] = $chr;	
				} elsif ($chr eq 'r'){
					$shipDesign = "";
					for my $row (@ship){
						$shipDesign .= join "", @{$row};
						$shipDesign .= "\n";
					}
					$ship = CaptainAscii::Ship->new($shipDesign, 0, 0, 'self');
					$self->{ship} = $ship;
				} elsif ($chr eq 'q'){
					$shipDesign = "";
					for my $row (@ship){
						$shipDesign .= join "", @{$row};
						$shipDesign .= "\n";
					}
					$ship = CaptainAscii::Ship->new($shipDesign, 0, 0, 'self');
					$self->{ship} = $ship;
					$designing = 0;
				}
			}
			usleep(1000);
		}
	}
	return $shipDesign;
}


sub _loadShip {
	my $self = shift;
	my $shipStr = shift;
	my $color = shift;
	$| = 1;

#	open (my $fh, '<', $ship_file) or die "failed to open $ship_file\n";
	# TODO don't send the ship until it successfully loads locally
#	while(my $line = <$fh>){
#		print $line;
#		$shipStr .= $line;
#		print {$self->{'socket'}} $line;
#	}
#	close ($fh);

	print {$self->{socket}} $shipStr;

	if ($color){
		print {$self->{socket}} "OPTION:color=$color\n";
	}
	print {$self->{socket}} "OPTION:name=" . getpwuid( $< ) . "\n";
	print {$self->{socket}} "DONE\n";
	select STDOUT;
	$self->{ship} = CaptainAscii::Ship->new($shipStr, 5, 5, 'self', {color => $color});
	$self->_addShip($self->{ship});
	
	return 1;
}

sub _getShips {
	my $self = shift;
	return values %{$self->{ships}};
}

sub _getShipCount {
	my $self = shift;
	return scalar $self->_getShips();
}

sub _removeShip {
	my $self = shift;
	my $id = shift;
	delete $self->{ships}->{$id};
}

sub _addShip {
	my $self = shift;
	my $ship = shift;
	$self->{ships}->{$ship->{id}} = $ship;
}

sub _getShip {
	my $self = shift;
	my $id = shift;
	#$self->{debug} = $id;
	return $self->{ships}->{$id};
}

sub loop {
	my $self = shift;

	my $lastTime  = time();
	my $frames = 0;
	my $time = time();
	my $fps = $self->{maxFps};

	my $scr = new Term::Screen;
	$scr->clrscr();
	$scr->noecho();
    #
	$self->{scr} = $scr;
	my $lastPing = time();

	$self->setHandlers();
	$self->printBorder();

	$self->_resetLighting($self->{width} * $self->{zoom}, $self->{height} * $self->{zoom});

	my $playing = 1;
	while ($playing){
		if ((time() - $time) < (1 / $fps)){
			my $sleep = 1_000_000 * ((1 / $fps) - (time() - $time));
			if ($sleep > 0){
				usleep($sleep);
			}
			next;
		}
		$lastTime = $time;
		$time = time();
		$frames++;
		if ($time - $lastFrame > 1){
			$lastFrame = $time;
			$self->{fps} = $frames;
			$frames = 0;
			$self->{lastFrame} = $time;
		}

		if (time() - $lastPing > 1){
			print {$self->{socket}} "z\n";
		}

		$self->_sendKeystrokesToServer($scr);
		$self->_getMessagesFromServer();

		$self->{'map'} = $self->_resetMap($self->{width} * $self->{zoom}, $self->{height} * $self->{zoom});

		$self->_resetLighting($self->{width} * $self->{zoom}, $self->{height} * $self->{zoom});

		my $cenX = int(($self->{width} * $self->{zoom})  / 2);
		my $cenY = int(($self->{height} * $self->{zoom}) / 2);
		my $offx = $cenX - int($self->{ship}->{x});
		my $offy = $cenY - int($self->{ship}->{y});

		$self->{cenX} = $cenX;
		$self->{cenY} = $cenX;

		$self->{offx} = $offx;
		$self->{offy} = $offy;

        $self->_drawLighting($offx, $offy);
		$self->_drawBullets($offx, $offy);
		$self->_drawItems($offx, $offy);
		$self->_drawShips($offx, $offy);

		if ($self->{mode} eq 'zonemap'){
			$self->printZoneScreen($scr);
		} else {
			$self->printScreen($scr);
		}
		$self->printInfo();
		$self->printSide();
	    $self->_resetLighting($self->{width} * $self->{zoom}, $self->{height} * $self->{zoom});
	}
}

sub printCursesScreen {
    my $self = shift;
    $self->{_curses_map}->prefresh(0, 0, 0, 0, $self->{height}, $self->{width});
    $self->{_curses_info}->refresh();
    $self->{_curses_side}->refresh();
    # copywin(*srcwin, *dstwin, sminrow, smincol, dminrow, dmincol, dmaxrow, dmaxcol, overlay)
	my $copyWin = $self->{_curses_mapBlank};
	my $warp = $self->{ship}->getStatus('warp');
	if ($warp){
		if ($warp->{end} - time() < 0.2){
			$copyWin = $self->{_curses_mapBlankNS4};
        } elsif ($warp->{end} - time() < 0.5){
			$copyWin = $self->{_curses_mapBlankNS3};
        } elsif ($warp->{end} - time() < 0.75){
			$copyWin = $self->{_curses_mapBlankNS2};
		} else {
			$copyWin = $self->{_curses_mapBlankNS};
		}
	}
    my $r = copywin(
        $copyWin,
        $self->{_curses_map},
        $self->{ship}->{y} % $starMapSize,
        $self->{ship}->{x} % $starMapSize,
        0,
        0,
        $self->{height},
        $self->{width},
        0
    );
}

sub printZoneScreen {
	my $self = shift;
	my $scr = shift;
	
	my $map = $self->{map};

	### draw the screen to Term::Screen
	foreach my $i (0 .. $self->{height}){
		my $iZ = (int($i * $self->{zoom}));
		my $row = '';
		foreach my $j (0 .. $self->{width}){
			my $jZ = (int($j * $self->{zoom}));
		}
	}
}

sub printScreen {
	my $self = shift;
	if($useCurses){ return $self->printCursesScreen(); }
	my $scr = shift;
	my $map = $self->{map};

	### draw the screen to Term::Screen
	foreach my $i (0 .. $self->{height}){
		my $iZ = (int($i * $self->{zoom}));
		my $row = '';
		foreach (0 .. $self->{width}){
			my $jZ = (int($_ * $self->{zoom}));
			my $lighting = $lighting[$iZ]->[$jZ];
			my $color = getColor('', 'ON_GREY' . ($lighting <= 23 ? $lighting : 23 ));
            $row .= (defined($map->[$iZ]->[$jZ]) ? $color . $map->[$iZ]->[$jZ] : $color . $self->getStar($i, $_));
		}
        $self->putStr(
            $i + 1, 1,
            $row
        );
	}
}

sub getStar {
    #my $self = shift;
    #my ($x, $y) = @_;
	# Do not assign variables for performance
	return substr($starMapStr[
		int($_[1] + $_[0]->{ship}->{y}) % $starMapSize],
		int($_[2] + $_[0]->{ship}->{x}) % $starMapSize,
		1); 
}

sub putTermChr {
    my $self = shift;
    my ($window, $col, $row, $str, $color, $backColor) = @_;

    my $colorBack = undef;
    if (!defined($color)){ $color = 'WHITE'; }
    if (!defined($colorBack)){ $colorBack = 'ON_BLACK'; }
    $col += $self->{height};
    $self->{scr}->at($col, $row);
    $self->{scr}->puts(getColor($color, $colorBack) . $str);
}

sub putStr {
	if ( ! onMap($_[0], $_[1], $_[2]) ){ return 0; }
    if ($useCurses){
        my $self = shift;
        if ($self->{zoom} == 1){
            return putCursesChr($self->{_curses_map}, @_);
        } else {
            return putCursesChr($self->{_curses_map}, $_[0] / $self->{zoom}, $_[1] / $self->{zoom}, $_[2], $_[3]);
        }
    } else {
        return putTermChr(@_);
    }
}

sub putInfoStr {
    my $self = shift;
    if ($useCurses){
        return putCursesChr($self->{_curses_info}, @_);
    } else {
        return putTermChr(@_);
    }
}

sub putSideStr {
    my $self = shift;
    if ($useCurses){
        return putCursesChr($self->{_curses_side}, @_);
    } else {
        return putTermChr(@_);
    }
}

sub putCursesChr {
    my ($window, $col, $row, $str, $color, $backColor) = @_;
    if (defined($color) && defined($backColor)){
        setCursesColor($window, $color, $backColor);
    }
	$str = sprite($str);
    $window->addstr($col, $row, $str);
    $window->attrset(A_NORMAL);
}

sub putMapStr {
	if ( ! onMap($_[0], $_[1], $_[2]) ){ return 0; }
    putStr(@_);
}

######### chat or parts #########
sub printSide {
	my $self = shift;
	my $options = shift;

	my $ship = $self->{ship};
	#my $height = (defined($options->{height}) ? $options->{height} : $self->{height} + 1);
	my $height = $self->{height} + 1;

	if ($self->{mode} eq 'build'){ # parts
		my $sprintf = '%3s │ %5s │ %6s │ %6s │ %6s │ %5s │ %5s │ %5s';
		if (!defined($self->{partsDisplay})){
			my %parts = %{ $ship->getAllPartDefs() };
			$self->{partsDisplay} = [];
			foreach my $ref (
            sort {
                defined($parts{$a}->{damage}) <=> defined($parts{$b}->{damage}) ||
                defined($parts{$a}->{thrust}) <=> defined($parts{$b}->{thrust}) ||
                defined($parts{$a}->{power})  <=> defined($parts{$b}->{power}) ||
                defined($parts{$a}->{shield}) <=> defined($parts{$b}->{shield}) ||
                $parts{$a}->{cost} <=> $parts{$b}->{cost}
            }
            keys %parts){
				my $part = $parts{$ref};
				if (defined($part->{show})){
					next if ($part->{show} eq 'no');
				}
				push(@{ $self->{partsDisplay} },
					sprintf($sprintf,
						$ref,
						'x' . $ship->hasSparePart($ref),
						'$' . $part->{cost},
						(defined($part->{thrust}) ? $part->{thrust} : ''),
						(defined($part->{power}) ? $part->{power} : ''),
						(defined($part->{damage}) ? $part->{damage} : ''),
						(defined($part->{rate}) ? $part->{rate} : ''),
						(defined($part->{shield}) ? $part->{shield} : ''),
					)
				);
			}
			$self->{partOffset} = 0;
		}

		$self->putSideStr(
            2, 3,
            sprintf($sprintf,
			'chr', 'owned', 'cost', 'thrust', 'power', 'dam', 'RoF', 'shield')
        );
		$self->putSideStr(
            3, 3,
            '────┼───────┼────────┼────────┼────────┼───────┼───────┼───────'
        );
		for my $line (4 .. $height){
			my $partLine = $self->{partsDisplay}->[$line - 3];
			$self->putSideStr(
                $line, 3,
                sprintf('%-' . ($self->{chatWidth} - 4) . 's',
				    (defined($partLine) ? $partLine : "")
				)
			);
		}
	} else { # chat
		for my $line (1 .. $height){
			$self->putSideStr(
                $line, 3,
                ' ' x ($self->{chatWidth} - 4)
            );
		}
		my $lastMsg = $#{ $self->{msgs} } + 1 + $self->{chatOffset};
		my $term = $lastMsg - $height - 4;
		my $count = 2;
		if ($term < 0){ $term = 0; }
		while ($lastMsg > $term){
			$count++;
			$lastMsg--;
			my $msgLine = $self->{msgs}->[$lastMsg];
			if ($msgLine){
				$self->putSideStr(
                    $height - $count,
					4,
                    sprintf('%-' . $self->{chatWidth} . 's', $msgLine->{msg}),
					'GREEN',
					#$msgLine->{color},
					'ON_BLACK'
                );
			}
		}
		my $boxColor = 'ON_BLACK';
		if ($self->{mode} eq 'type'){ $boxColor = 'ON_GREY4'; }
		$self->putSideStr(
            $height - 2,
			0,
            sprintf('%-' . $self->{chatWidth} . 's', "> " . substr($self->{'msg'}, -($self->{chatWidth} -3))),
            "WHITE",
			$boxColor
        );
	}

}

sub printStatusBar {
    my $self = shift;
    my ($name, $value, $max, $width, $col, $row, $r, $g, $b) = @_;


    my $statBar = '';
	my $ratio = $value / $max;
	if ($ratio > 1){ $ratio = 1; }
	if ($ratio < 0){ $ratio = 0; }
	my $fullWidth = $width * $ratio;
	my $emptyWidth = ($width - $fullWidth + 1);
	
	if ($r eq 'x'){ $r = int($ratio * 5); }
	if ($g eq 'x'){ $g = int($ratio * 5); }
	if ($b eq 'x'){ $b = int($ratio * 5); }
	if ($r eq '-x'){ $r = int((1 - $ratio) * 5); }
	if ($g eq '-x'){ $g = int((1 - $ratio) * 5); }
	if ($b eq '-x'){ $b = int((1 - $ratio) * 5); }

    if ($max < 1000){
        $statBar = sprintf('|' x int($width / 3) . '%3d' . ' ' x int($width / 3) . '%3d' . ' ' x int($width / 3), $max * 0.33, $max * 0.66);
    } else {
        $statBar = sprintf('=' x int($width / 3) . '%3d' . ' ' x int($width / 3) . '%3d' . ' ' x int($width / 3), $max * 0.33, $max * 0.66);
    }
    
    my $widthStatus = $width - length($name);
    $self->putInfoStr(
        $col, $row,
        '╭' . '─' x floor($widthStatus / 2) . uc($name) . '─' x ceil($widthStatus / 2) . '╮'
    );

    $self->putInfoStr(
        $col + 1, 0,
        "│"
    );
    $self->putInfoStr(
        $col + 1, $row + 1,
        ' ' x $fullWidth,
		'WHITE',
		'ON_RGB' . $r . $g . $b
    );
    $self->putInfoStr(
        $col + 1, $row + $fullWidth + 1,
        ' ' x $emptyWidth
    );
    $self->putInfoStr(
        $col + 1, $width + 1,
        "│"
    );
    $self->putInfoStr(
        $col + 2, $row,
        '╰' . '─' x $width . '╯'
    );
}

sub printInfo {
	my $self = shift;
	my $options = shift;

	if ((time() - $self->{lastInfoPrint}) < (1 / $self->{maxInfoFps})){
		return;
	}
    $self->printBorder();

	my $ship = $self->{ship};
	#my $height = (defined($options->{height}) ? $options->{height} : $self->{height} + 1);
	my $height = $self->{height} + 1;
	my $width = $self->{width};
	my $left = 2;

	#### ----- ship info ------ ####
    $self->putInfoStr(0, 0, "fps: $self->{fps}  ", 'GREEN', "ON_BLACK");
    #### Status display
    my %status = (
        'Weight'       => int $ship->getStatus('weight'),
        'Coordinates'  => sprintf('%3s,%3s', int($ship->{x}), int($ship->{y})),
        'Max Thrust'   => int $ship->getStatus('thrust'),
        'Speed'        => sprintf('%.1f', $ship->getStatus('currentSpeed')),
        'Inertia'      => sprintf('%.1f', $ship->getStatus('inertia')),
        'Acceleration' => sprintf('%.3f', $ship->getStatus('acceleration')),
        'Ship Value'   => '$' . int $ship->getStatus('cost'),
        'Cash'         => '$' . int $ship->getStatus('cash'),
        'Power Rate'   => sprintf('%.1f', $ship->getStatus('currentPowerGen')),
    );
    my $keyLen = 5;
    my $valLen = 5;
    foreach my $key (keys %status){
        if (length($key) > $keyLen){ $keyLen = length($key); }
        if (length($status{$key}) > $valLen){ $valLen = length($status{$key}); }
    }
	$self->putInfoStr(
        1, 52,
        '┌──' . '─' x $keyLen . '┬' . '─' x $valLen . '──┐'
    );
    my $i = 0;
    for my $key (sort keys %status){
        $i++;
	    $self->putInfoStr(
            1 + $i, 52,
            sprintf('│ %' . $keyLen . 's │ %' . $valLen . 's │', $key, $status{$key})
        );
    }
	$self->putInfoStr(
        2 + $i, 52,
        '└──' . '─' x $keyLen . '┴' . '─' x $valLen . '──┘'
    );

    

	my @ships = keys %{$self->{ships}};
	#$self->{debug} = join ',', @ships;
    $self->putInfoStr(4, 1, "debug: $self->{debug}  ", 'GREEN', "ON_BLACK");

	my $barWidth = 50;

    #my ($name, $value, $max, $width, $col, $row, $r, $g, $b) = @_;
	$self->printStatusBar(
		'power',
		$self->{ship}->getStatus('currentPower'),
		$self->{ship}->getStatus('power'),
		50,
		1,
		0,
		'5',
		'x',
		0
	);
	$self->printStatusBar(
		'shields',
		$self->{ship}->getStatus('shieldHealth'),
		$self->{ship}->getStatus('shield'),
		50,
		4,
		0,
		'-x',
		'x',
		'5'
	);
	$self->printStatusBar(
		'health',
		$self->{ship}->getStatus('currentHealth'),
		$self->{ship}->getStatus('health'),
		50,
		7,
		0,
		'-x',
		'x',
		'0'
	);
	$self->printStatusBar(
		'thrust',
		$self->{ship}->getStatus('currentThrust'),
		$self->{ship}->getStatus('thrust'),
		50,
		10,
		0,
		'-x',
		'x',
		'0'
	);

	########## modules #############
    my $mHeight = 1;
    $self->putInfoStr(
        $mHeight, $width + 2,
        '┌────────────────────┬───────────┐'
    );

	foreach my $module ( sort $ship->getModules){
        # TODO grey for you don't even have the module
		my $color = $module->getColor($ship);
        $mHeight++;
        $self->putInfoStr(
            $mHeight, $width + 2,
            sprintf('│ %-18s │ %-9s │', $module->name(), join (',', $module->getKeys())),
			$color, 'ON_BLACK'
        );
	}
    $self->putInfoStr(
        $mHeight, $width + 2,
        '└────────────────────┴───────────┘'
    );

    return 0; 
}

sub _resetMap {
	my $self = shift;
	my ($width, $height) = @_;
	my @map = ();

	if ($useCurses){
		return [];
	}

	foreach my $x (0 .. $height){
		push @map, [(undef) x $width];
	}

	return \@map;
}

sub _resetLighting {
	my $self = shift;
	my ($width, $height) = @_;
	@lighting = ();
	foreach my $x (0 .. $height + 1){
		push @lighting, [(0) x ($width + 1)];
	}
}

sub _drawBullets {
	my $self = shift;

	my $offx = shift;
	my $offy = shift;

	my %bullets = %{ $self->{bullets} };
	foreach my $bulletK ( keys %bullets){
		my $bullet = $bullets{$bulletK};
		if ($bullet->{expires} < time()){
			delete $bullets{$bulletK};
			next;
		}
		my $spotX = $bullet->{x} + $offy;
		my $spotY = $bullet->{y} + $offx;
		if ($spotX > 0 && $spotY > 0){
            $self->setMap($spotX, $spotY, $bullet->{chr}, $bullet->{col});
		}
	}
}

sub _drawItems {
	my $self = shift;
	my $offx = shift;
	my $offy = shift;

	my %items = %{ $self->{items} };
	foreach my $itemK ( keys %items){
		my $item = $items{$itemK};
		if ($item->{expires} < time()){
			delete $items{$itemK};
			next;
		}
		my $spotX = $item->{x} + $offy;
		my $spotY = $item->{y} + $offx;
		if ($spotX > 0 && $spotY > 0){
			$self->setMap($spotX, $spotY, $item->{chr});
		}
	}
}

sub setHandlers {
	my $self = shift;
	$SIG{WINCH} = sub { $self->resizeScr() };
}

sub resizeScr {
	my $self = shift;
	use Term::ReadKey;
	my ($wchar, $hchar, $wpixels, $hpixels) = GetTerminalSize();
	$self->{width} = $wchar - $self->{chatWidth};
	$self->{height} = $hchar - 20;
	$self->{termWidth}  = $wchar;
	$self->{termHeight} = $hchar;

	if (defined($self->{scr})){
		$self->{scr}->clrscr();
		$self->printBorder();
	}
}

sub printBorder {
	my $self = shift;

	my $color = $self->borderColor();

    if ($useCurses){

    } else {
        $self->putStr(
            0, 0,
            "╔" . "═" x ($self->{width} + 1) . "╦" . "═" x ($self->{chatWidth} - 4). "╗",
            $color
        );
        $self->putStr(
            $self->{height} + 2, 0,
            "╚" . "═" x ($self->{width} + 1) . "╩" . "═" x ($self->{chatWidth} - 4). "╝",
            $color
        );
        foreach my $i (1 .. $self->{height} + 1){
            $self->putStr(
                $i, 0,
                "║",
                $color
            );
            $self->putStr(
                $i, $self->{width} + 2,
                "║",
                $color
            );
            $self->putStr(
                $i, $self->{width} + $self->{chatWidth},
                "║",
                $color
            );
        }
    }
}

sub borderColor {
	my $self = shift;
    if (time() - $self->{'ship'}->getStatus('lastHit') < 0.2){
        return 'RED ON_BLACK';
    } elsif (time() - $self->{ship}->getStatus('lastShieldHit') < 0.2){
        return 'BLUE ON_BLACK';
    } else {
        return 'WHITE ON_BLACK';
    }
}

sub setMapString {
    # TODO enable
    return 0;
	my $self = shift;
	my ($string, $x, $y, $color) = @_;
	my @ar = split("", $string);
	my $dy = 0;
	foreach my $chr (@ar){
		$self->setMap($x, $y + $dy, $chr, $color);
		$dy++;
	}
}

sub _drawLighting {
	my $self = shift;	

	my $offx = shift;
	my $offy = shift;

	my $time = time();

	foreach my $ship ($self->_getShips()){
		if ($ship->{shieldsOn} && !($self->{mode} eq 'build' && $ship->{id} eq $self->{ship}->{id})){
			foreach my $part ($ship->getParts()){
				# TODO x and y switched
				my $px = ($offy + int($ship->{y})) + $part->{'y'};
				my $py = ($offx + int($ship->{x})) + $part->{'x'};

				if ($part->{'part'}->{'type'} eq 'shield'){
					if ($part->{'shieldHealth'} > 0){
						my $shieldLevel = ((time() - $part->{'hit'} < .3) ? $part->{part}->{shieldlight} + 3 : $part->{part}->{shieldlight});
                        if ($ship->getStatus('deflector')){ $shieldLevel += 2; }
						my $radius = $part->{'part'}->{'shieldsize'};
						foreach my $sh_x (-$radius * ASPECTRATIO .. $radius * ASPECTRATIO){
							foreach my $sh_y (-$radius .. $radius){
								if (sqrt((($sh_x / ASPECTRATIO ) ** 2) + ($sh_y ** 2)) <= $radius){
									$self->addLighting($px + $sh_x, $py + $sh_y, $shieldLevel);
								}
							}
						}
					}
				}
			}
		} # end if shields are on
	}

    foreach my $light ($self->_getLights()){
		my $level = int($light->{level} - ((time() - $light->{start}) * $light->{decay}));
		if ($level < 1){
			delete $lights{$light->{'key'}};
		} else {
			$self->addLighting($light->{x} + $offy, $light->{y} + $offx, $light->{level});
		}
    }
}

sub _getLights {
    my $self = shift;
	return values %lights;
}

sub _drawShips {
	my $self = shift;	
	my ($offx, $offy) = @_;

	my $time = time();

	foreach my $ship ($self->_getShips()){
		my $taunt = $ship->getStatus('taunt');
		#if ($taunt && (time() - $ship->{lastTauntTime} > 8)){
		if ($taunt && (time() - $ship->{lastTauntTime} < 8)){
			my $tx = $offy + int($ship->getShipTop() - 2);
			my $ty = $offx + int($ship->getShipLeft());
			$self->setMapString($taunt, $tx, $ty);
		}
		foreach my $part ($ship->getParts()){
			my $highlight = ((time() - $part->{'healing'} < .3 ) ? 'ON_RGB020' : ((time() - $part->{'hit'} < .3) ? 'ON_RGB222' : ''));
			my $bold = '';
			if (defined($part->{lastShot})){
				$bold = (($time - $part->{'lastShot'} < .3) ? 'bold' : 'clear');
			}
			my $timeRainbow = int($time * 2);
			my $rainbow = "RGB" . abs( 5 - ($timeRainbow % 10)) . abs( 5 - (($timeRainbow + 3) % 10)) . abs( 5 - (($timeRainbow + 6) % 10));

			my $partColor = $part->{'part'}->{'color'} ne 'ship' ?
				( $part->{'part'}->{color} eq 'rainbow' ? $rainbow : $part->{'part'}->{color} )
				: $ship->{color};

			# TODO x and y switched
			my $px = ($offy + int($ship->{y})) + $part->{'y'};
			my $py = ($offx + int($ship->{x})) + $part->{'x'};

			my $chr = $part->{chr};
			if ( (rand() - 0.3) > ($part->{'health'} / $part->{'part'}->{'health'} ) ){ $chr = ' '; }
			
			# TODO have it fade to black?
			if ($ship->{cloaked}){
				# remove coloring TODO change to color + chr

				if ($ship->{id} eq $self->{ship}->{id}){
					$self->setMap($px, $py, $chr, 'GREY3');
				} else {
					$self->setMap($px, $py, $chr, 'GREY0');
				}
			} else { 
                # TODO highlight adds to lighting
                $self->setMap($px, $py, $chr, $partColor);
			}
		}
		my ($aimx, $aimy) = $ship->getAimingCursor();
		my $px = ($offy + int($ship->{y})) + $aimx;
		my $py = ($offx + int($ship->{x})) + $aimy;
		if ($self->{ship}->{id} eq $ship->{id}){ # draw the aiming dot for yourself
			$self->setMap($px, $py, '+','GREEN');
		} elsif ($self->{ship}->{radar}){ # if your radar is active
			($aimx, $aimy) = $self->{ship}->getRadar($ship);
			$px = ($offy + int($self->{ship}->{y})) + $aimx;
			$py = ($offx + int($self->{ship}->{x})) + $aimy;
			if (!$ship->{cloaked}){
				if ($ship->{isBot}){
					$self->setMap($px, $py, "+", 'RED ON_BLACK');
				} else {
					$self->setMap($px, $py, "+", 'BRIGHT_BLUE ON_BLACK');
				}
			}
		}
		if (($self->{'mode'} eq "build") && ($self->{ship}->{id} eq $ship->{id})){
		#if (($self->{ship}->{id} eq $ship->{id})){
			my $cx = ($offy + int($ship->{y})) + $self->{'cursorx'};
			my $cy = ($offx + int($ship->{x})) + $self->{'cursory'};
			$self->setMap($cx, $cy, '+', "BLACK", "ON_WHITE");
		}
	}
}

sub _sendKeystrokesToServer {
	my $self = shift;	
	my $scr = shift;

	# send keystrokes
	if ($self->{mode} eq 'drive'){
		while ($scr->key_pressed()){ 
			#my $chr = $scr->getch();
			my $chr = getch();
			if ($chr eq '`'){
				$self->{'mode'} = 'build';
				$self->{'cursorx'} = 0;
				$self->{'cursory'} = 0;
			} elsif ($chr eq '/'){
				$self->{'msg'} = '/';
				$self->{'mode'} = 'type';
			} elsif ($chr eq "\r"){
				$self->{'mode'} = 'type';
			} elsif ($chr eq "pgup"){
				$self->{chatOffset}--;
			} elsif ($chr eq "pgdn"){
				$self->{chatOffset}++;
				if ($self->{chatOffset} > 0){ $self->{chatOffset} = 0; }
			} elsif ($chr eq "-"){
				$self->{zoom}++;
			} elsif ($chr eq "+"){
				$self->{zoom}--;
				if ($self->{zoom} < 1){ $self->{zoom} = 1; }
			} else {
				print {$self->{socket}} "$chr\n";
			}
		}
	} elsif($self->{mode} eq 'build') {
		while ($scr->key_pressed()){ 
			my $chr = $scr->getch();
			if ($chr eq '`'){
				$self->{'mode'} = 'drive';
			}
			elsif ($chr eq 'a'){ $self->{'cursory'}--; }
			elsif ($chr eq 'd'){ $self->{'cursory'}++; }
			elsif ($chr eq 's'){ $self->{'cursorx'}++; }
			elsif ($chr eq 'w'){ $self->{'cursorx'}--; }
			elsif (defined($self->{ship}->getPartDef($chr))){
				#add part
				print {$self->{socket}} "B:$self->{'cursorx'}:$self->{'cursory'}:$chr\n";
			} elsif ($chr eq ' '){
				print {$self->{socket}} "B:$self->{'cursorx'}:$self->{'cursory'}: \n";
				#remove part
			}
		}
	} elsif($self->{mode} eq 'type'){
		while ($scr->key_pressed()){ 
			{
				local $/ = undef;
				my $chr = $scr->getch();
				if ($chr eq "\r"){
                    if ($self->{'msg'} eq '/exit'){
                        endwin;
                        exit;
                    } else {
					    print {$self->{socket}} "M:$self->{username}:$self->{'msg'}\n";
                    }
					$self->{'msg'} = '';
					$self->{mode} = 'drive';
				} elsif($chr eq "\b" || ord($chr) == 127){ # 127 is delete
					chop($self->{'msg'});
				} else {
					$self->{'msg'} .= $chr;
				}
			}
		}
	}
}

# get messages from the server
sub _getMessagesFromServer {
	my $self = shift;
	my $socket = $self->{socket};
	my $bullets = $self->{bullets};
	while (my $msgjson = <$socket>){
		my $msg;
		eval {
			$msg = decode_json($msgjson);
		};
		if (! defined($msg)){ next; }
		my $data = $msg->{d};
		if ($msg->{c} eq 'b'){ # bullet msg
			my $key = $data->{k};
			# new bullet
			if (!defined($self->{bullets}->{$key})){
				if (my $ship = $self->_getShip($data->{sid})){
					my $part = $ship->getPartById($data->{pid});
					$part->{'lastShot'} = time();
				} else {
					#$self->{debug} = "ship not found $data->{sid}";
				}
				$self->{bullets}->{$key} = $data;
				$self->{bullets}->{$key}->{expires} = time() + $data->{ex}; # set absolute expire time
			} else {
				$self->{bullets}->{$key}->{x} = $data->{x};
				$self->{bullets}->{$key}->{y} = $data->{y};
			}
		} elsif ($msg->{c} eq 'item'){
			my $key = $data->{k};
			$self->{items}->{$key} = $data;
			$self->{items}->{$key}->{expires} = time() + $data->{ex}; # set absolute expire time
			#$self->{debug} = "added item $key\n";
		} elsif ($msg->{c} eq 'itemdel'){
			my $key = $data->{k};
			delete $self->{items}->{$key};
		} elsif($msg->{c} eq 'exit'){
			$self->exitGame($data->{'msg'});
		} elsif ($msg->{c} eq 'newship'){
			my $shipNew = CaptainAscii::Ship->new($data->{design}, $data->{x}, $data->{y}, $data->{id}, $data->{options});
			if ($data->{'map'}){
				$shipNew->_loadShipByMap($data->{'map'});
			}
			if ($data->{'isBot'}){
				$shipNew->{'isBot'} = $data->{'isBot'};
			}
			$self->_addShip($shipNew);
		} elsif ($msg->{c} eq 'dam'){
			#$debug = $data->{bullet_del} . " - " . exists($bullets{$data->{bullet_del}});
			if (defined($data->{bullet_del})){
				delete $self->{bullets}->{$data->{bullet_del}};
			}
			foreach my $s ($self->_getShips()){
				if ($s->{id} eq $data->{ship_id}){
					if (defined($data->{shield})){
						$s->damageShield($data->{id}, $data->{shield});
					}
					if (defined($data->{health})){
						my $light = $s->setPartHealth($data->{id}, $data->{health});
						if (defined($light)){
							addLight($light);
						}
					}
				}
			}
		} elsif ($msg->{c} eq 'light'){
			addLight($data);
			$self->{debug} = 'light ' . time();
		} elsif ($msg->{c} eq 'shipdelete'){
			$self->_removeShip($data->{id});
		} elsif ($msg->{c} eq 'shipchange'){
			foreach my $s ($self->_getShips()){
				if ($s->{id} eq $data->{'ship_id'}){
					$s->_loadShipByMap($data->{'chr_map'}, $data->{'part_map'});
				}
			}
		} elsif ($msg->{c} eq 'setShipId'){
			foreach my $s ($self->_getShips()){
				if ($s->{id} eq $data->{'old_id'}){
					$self->{ships}->{$data->{'new_id'}} = $self->{ships}->{$data->{'old_id'}};
					$s->{id} = $data->{'new_id'};
					delete($self->{ships}->{$data->{'old_id'}});
					#$self->{debug} = "$data->{'old_id'} to $data->{'new_id'}";
				}
			}
		} elsif ($msg->{c} eq 'shipstatus'){
			# TODO just get the ship by id
			foreach my $s ($self->_getShips()){
				$s->recieveShipStatusMsg($data);
			}
		} elsif ($msg->{c} eq 'msg'){
			my $msgStringFull = "";
            if ($data->{'user'}){
				$msgStringFull .= sprintf('%-10s: %s', $data->{'user'}, $data->{'msg'});
            } else {
				$msgStringFull .= $data->{'msg'};
            }
			$Text::Wrap::columns = $self->{chatWidth} - 10;
			my @wrappedMsgs = split("\n", wrap("", "  ", $msgStringFull));
			foreach my $msgString (@wrappedMsgs){
			if (!defined($data->{'color'})){
				$data->{'color'} = 'GREEN';
			}
			push @{ $self->{msgs} }, { msg => $msgString, color => $data->{'color'} };
			}
        } elsif ($msg->{c} eq 'sparepart'){
			if (defined($data->{add})){
				$self->{ship}->addSparePart($data->{'part'}, $data->{add});
			} elsif(defined($data->{use})){
				$self->{ship}->useSparePart($data->{'part'}, $data->{use});
			}
			delete $self->{partsDisplay};
		}
	}
}

sub exitGame {
	my $self = shift;
	my $msg = shift;
    $self->putStr(
        $self->{height} / 2, $self->{width} / 2,
        $msg
    );
	print "\r\n" . "\n" x ($self->{height} / 3);
	exit;
}

sub _bindSocket {
	my $self = shift;
	my $socket_path = shift;
	my $socket = IO::Socket::UNIX->new(
		Type => SOCK_STREAM(),
		Peer => $socket_path,
	) or die "failed to open socket $socket_path\n";
	$self->{socket} = $socket;
}

sub setCursesColor {
	# Do not assign variables for performance
    #my ($window, $foregroundColor, $backgroundColor) = @_;
    my $colorId = $cursesColors{$_[1]}->{$_[2]};
    if (!defined($colorId)){
        $colorId = $cursesColorCount++;
        init_pair($colorId, $colorCodes{$_[1]}, $colorCodes{$_[2]});
        $cursesColors{$_[1]}->{$_[2]} = $colorId;
    }
    $_[0]->attrset(COLOR_PAIR($colorId));
    return undef;
}

sub getColor {
    #my ($foreground, $background) = @_;
	# Do not assign variables for performance
    if (!defined($colors{$_[0]})){
        $colors{$_[0]} = color($_[0]);
    }
    return $colors{$_[0]};
}

sub setMap {
	# $self->onMap($x, $y);
	if ( ! onMap($_[0], $_[1], $_[2]) ){ return 0; }
    my $lighting = 'ON_GREY' . $lighting[$_[1]]->[$_[2]];
	if ($useCurses){ return putStr(@_, $lighting); }

	my ($self, $x, $y, $chr, $color) = @_;
	if (!defined($color)){ $color = 'RESET' }
	$chr = sprite($chr);
	$self->{map}->[$x]->[$y] = getColor($color) . $chr;
}

sub addLight {
	my $light = shift;
	my $key = $lightsKey++;
	$light->{'key'} = $lightsKey;
	$light->{'start'} = time();
	$lights{$lightsKey} = $light;
}

sub addLighting {
	my $self = shift;
	my ($x, $y, $level) = @_;
	if ( ! $self->onMap($x, $y) ){ return 0; }
	my $newLevel = $lighting[$x]->[$y] + $level;
    if ($newLevel < 23){
	    $lighting[$x]->[$y] = $newLevel;
		if ($useCurses){
            if ($self->{zoom} == 1){
			    putCursesChr($self->{_curses_map}, $x, $y, ' ', 'WHITE', 'ON_GREY' . $newLevel);
            } else {
			    putCursesChr($self->{_curses_map}, $x / $self->{zoom}, $y / $self->{zoom}, ' ', 'WHITE', 'ON_GREY' . $newLevel);
            }
		}
    }
}

sub onMap {
	my $self = shift;
	my ($x, $y) = @_;
	return ($x > 0 && $y > 0 && $x < $self->{height} * $self->{zoom} && $y < $self->{width} * $self->{zoom});
}

1;
