#!/usr/bin/perl

use strict; use warnings;
package CaptainAscii::Factions;

my %factions = (
    'imperialist' => {
	    'buildConfig' => {
            'reflectX' => 1,
            'reflectY' => 1,
            'turnOdds' => 0.1,
            'branchOdds' => 0.4,
            'branchDir' => 'x',
            'endOdds'   => 0.1,
            'pieceOdds' => 0.2,    #non plate piece
            'sideOdds'  => 0.3,    #one off side pieces
            'capOdds'   => 1,    #ending cap piece
            'parts1' => {
                base   => ['-'],
                embedx => ['|', 'O'],
                embedy => ['_', 'O', '@'],
                up     => ['v', '\\', '/', '|'],
                down   => ['^', '\\', '/', '|'],
                right  => [')'],
                left   => ['('],
            },
            'parts2' => {
                base   => ['-'],
                embedx => ['|', 'O', '0'],
                embedy => ['_', 'O', '@', '$'],
                up     => ['v', '\\', '/', '|'],
                down   => ['^', '\\', '/', '|'],
                right  => [')', '}'],
                left   => ['(', '{'],
            },
            'parts3' => {
                base   => ['+'],
                embedx => ['|', 'O', '0', 'I', '$'],
                embedy => ['_', 'O', '@', '$', 'L'],
                up     => ['v', '\\', '/', '|'],
                down   => ['^', '\\', '/', '|'],
                right  => ['}'],
                left   => ['{'],
            },
        },
    },
    'communist'   => {
        'buildConfig' => {
            'reflectX' => 1,
            'reflectY' => 0,
            'turnOdds' => 0.2,
            'branchOdds' => 0.2,
            'branchDir' => 'y',
            'endOdds'   => 0.1,
            'pieceOdds' => 0.2,    #non plate piece
            'sideOdds'  => 0.2,    #one off side pieces
            'capOdds'   => 1,    #ending cap piece
            'parts1' => {
                base   => ['-'],
                embedx => ['|', 'H', 'O'],
                embedy => ['_', 'O', '@'],
                up     => ['v', '\\', '/', 'H', '|', 'H'],
                down   => ['^', '\\', '/', 'H', '|', 'H'],
                right  => [')'],
                left   => ['('],
            },
            'parts2' => {
                base   => ['-'],
                embedx => ['|', 'H', 'O', '$'],
                embedy => ['_', 'O', '@'],
                up     => ['v', '\\', '/', '8', '|', 'H', 'H'],
                down   => ['^', '\\', '/', '8', '|', 'H', 'H'],
                right  => ['}'],
                left   => ['{'],
            },
            'parts3' => {
                base   => ['-'],
                embedx => ['|', 'H', 'O'],
                embedy => ['_', 'O', '@'],
                up     => ['v', '\\', '/', '8', '|'],
                down   => ['^', '\\', '/', '8', '|'],
                right  => [')'],
                left   => ['('],
            },
        },
    },
    'alien'       => {
        'buildConfig' => {
            'reflectX' => 1,
            'reflectY' => 0,
            'turnOdds' => 0.45,
            'branchOdds' => 0.4,
            'branchDir' => 'x',
            'endOdds'   => 0.1,
            'pieceOdds' => 0.2,    #non plate piece
            'sideOdds'  => 0.2,    #one off side pieces
            'capOdds'   => 0.8,    #ending cap piece
            'parts1' => {
                base   => ['\''],
                embedx => ['N', 'P'],
                embedy => ['N', 'P'],
                up     => ['w', 'N'],
                down   => ['w', 'N'],
                right  => ['O', 'w'],
                left   => ['O', 'w'],
            },
            'parts2' => {
                base   => ['\''],
                embedx => ['N', 'P'],
                embedy => ['N', 'P'],
                up     => ['w', 'N', 'W'],
                down   => ['w', 'N', 'W'],
                right  => ['P', 'w', 'c'],
                left   => ['P', 'w', 'c'],
            },
            'parts3' => {
                base   => ['\'', '"'],
                embedx => ['N', 'P'],
                embedy => ['N', 'P'],
                up     => ['w', 'N', 'W'],
                down   => ['w', 'N', 'W'],
                right  => ['P', 'w', 'C'],
                left   => ['P', 'w', 'C'],
            },
        },
    },
    'nihilist'    => {
        'buildConfig' => {
            'reflectX' => 0,
            'reflectY' => 0,
            'turnOdds' => 0.2,
            'branchOdds' => 0.2,
            'branchDir' => 'y',
            'endOdds'   => 0.1,
            'pieceOdds' => 0.2,    #non plate piece
            'sideOdds'  => 0.2,    #one off side pieces
            'capOdds'   => 1,    #ending cap piece
            'parts1' => {
                base   => ["-"],
                embedx => ['|', 'H', 'O'],
                embedy => ['_', 'O'],
                up     => ['v', 'H',],
                down   => ['^', '\\', '/','|'],
                right  => [')'],
                left   => ['('],
            },
            'parts2' => {
                base   => ["-"],
                embedx => ['|', 'H', 'O'],
                embedy => ['_', 'O'],
                up     => ['v', 'H',],
                down   => ['^', '\\', '/', '8', '|'],
                right  => [')'],
                left   => ['('],
            },
            'parts3' => {
                base   => ['+'],
                embedx => ['|', 'H', 'O'],
                embedy => ['_', 'O'],
                up     => ['v', '\\', '/', '8', '|'],
                down   => ['^', '\\', '/', '8', '|'],
                right  => [')'],
                left   => ['('],
            },
        },
    },
    'zealot'      => {
        'buildConfig' => {
            'reflectX' => 0,
            'reflectY' => 1,
            'turnOdds' => 0.05,
            'branchOdds' => 0.3,
            'branchDir' => 'x',
            'endOdds'   => 0.1,
            'pieceOdds' => 0.2,    #non plate piece
            'sideOdds'  => 0.2,    #one off side pieces
            'capOdds'   => 1,    #ending cap piece
            'parts1' => {
                base   => ['-'],
                embedx => ['|', 'H', 'O'],
                embedy => ['_', 'O', '@'],
                up     => ['v', '\\', '/', 'U', '|'],
                down   => ['^', '\\', '/', 'U', '|'],
                right  => [')'],
                left   => ['('],
            },
            'parts2' => {
                base   => ['+'],
                embedx => ['|', 'H', 'O'],
                embedy => ['_', 'O', '@'],
                up     => ['v', '\\', '/', '8', 'U', '|'],
                down   => ['^', '\\', '/', '8', 'U', '|'],
                right  => [')'],
                left   => ['('],
            },
            'parts3' => {
                base   => ['+'],
                embedx => ['|', 'H', 'O', 'M'],
                embedy => ['_', 'O', '@'],
                up     => ['v', '\\', '/', '8', 'I'],
                down   => ['^', '\\', '/', '8', 'I'],
                right  => ['{'],
                left   => ['}'],
            },
        },
    },
    'station'      => {
        'buildConfig' => {
            'reflectX' => 0,
            'reflectY' => 0,
            'turnOdds' => 0.04,
            'branchOdds' => 0.08,
            'branchDir' => 'x',
            'endOdds'   => 0.01,
            'pieceOdds' => 0.05,    #non plate piece
            'sideOdds'  => 0.05,    #one off side pieces
            'capOdds'   => 0.5,    #ending cap piece
            'parts1' => {
                base   => ['-'],
                embedx => ['|', 'H', 'O'],
                embedy => ['_', 'O', '@'],
                up     => ['v', '\\', '/', 'U', '|'],
                down   => ['^', '\\', '/', 'U', '|'],
                right  => [')'],
                left   => ['('],
            },
            'parts2' => {
                base   => ['+'],
                embedx => ['|', 'H', 'O'],
                embedy => ['_', 'O', '@'],
                up     => ['v', '\\', '/', '8', 'U', '|'],
                down   => ['^', '\\', '/', '8', 'U', '|'],
                right  => [')'],
                left   => ['('],
            },
            'parts3' => {
                base   => ['+'],
                embedx => ['|', 'H', 'O', 'M'],
                embedy => ['_', 'O', '@'],
                up     => ['v', '\\', '/', '8', 'I'],
                down   => ['^', '\\', '/', '8', 'I'],
                right  => ['{'],
                left   => ['}'],
            },
        },
    }
);

my @factionArray = (keys %factions);

my %quotes;
$quotes{communist}->{attack} = [
'No revolution can succeed without sacrifice.',
'Only through violence can lasting peace be achieved.',
'The universe belongs to all people.',
'Property is a crime against your fellow man.',
'You are a betrayer of the revolution.',
'The path of history is set.',
'The victory of communism is inevitible.',
'The blood of the righteous will not spill in vain.',
'History will absolve us.',
'All reactionaries will be purged.',
'Justice for all at any cost.',
'Not one step back in the fight against injustice',
'History is a dialectical process.',
'The people\'s army will wash over the universe.',
'None will stand against the people\'s army',
];
$quotes{communist}->{flee} = [
'On second thought maybe a few steps back are fine.',
'I must survive to continue to fight against injustice...',
];

$quotes{nihilist}->{attack} = [
'Those who suffer greatly do not fear death.',
'Death is certain. We can only choose the time to die.',
'Man alone can interpret his existence.',
'Life is a mistake.',
'The only evil is to not embrace your freedom.',
'Nothing will save us.',
'All roads end the same.',
'Eternal life would be eternal boredom.',
'It is better to have never been born.',
"That which does not kill you can still kill someone else",
];
$quotes{nihilist}->{flee} = [
'This fight is pointless...like life in general.',
];

$quotes{imperialist}->{attack} = [
'We will stamp out every communist and return order to the land.',
'Disobedience is seed of choas.',
'The empire will be restored.',
'Deviancy is a sickness of the mind.',
'The social order will be restored at any cost.',
];
$quotes{imperialist}->{flee} = [
'We will return to prosecute your crimes',
'Disorder will be stamped out. But maybe another time.',
];

$quotes{zealot}->{attack} = [
'God will judge every non-believer.',
'God does not play dice.',
'Science will not save us.',
'Only through faith and the anguish of life subside.',
'Life cannot be understood through reason alone.',
];
$quotes{zealot}->{flee} = [
'God will punish you for your sins.',
'Even failure is part of God\'s plan.',
];

sub getTaunt {
	my $faction = shift;
	my $type = shift;
	if (defined($quotes{$faction}->{$type})){
		my @taunts = @{ $quotes{$faction}->{$type} };
		return $taunts[rand @taunts];
	}
	return undef;
}

sub getBuildConfig {
    my $faction = shift;
    return $factions{$faction}->{'buildConfig'};
}

sub getRandomFaction {
    return $factionArray[rand @factionArray]; 
}

1;
