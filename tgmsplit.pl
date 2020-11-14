#!/usr/bin/perl -w
use strict;
use POSIX qw(floor);
use Term::Screen;
use Term::ANSIColor;
use Switch;

my $term = Term::Screen->new();
$term->curinvis();

my $split_file = "splits.pb";
my @grade = qw(9 8 7 6 5 4 3 2 1 S1 S2 S3 S4 S5 S6 S7 S8 S9 Gm);
my @sec_labels = (
	"  0-100", "100-200", "200-300",
	"300-400", "400-500", "500-600",
	"600-700", "700-800", "800-900",
	"900-999");

my @gold_st  = qw(0 0 0 0 0 0 0 0 0 0 0);
my @splits   = qw(0 0 0 0 0 0 0 0 0 0 0);
my @split_st = qw(0 0 0 0 0 0 0 0 0 0 0);
my @stats = qw(0 0 0);

my @current_splits = qw(0 0 0 0 0 0 0 0 0 0 0);
my @current_st     = qw(0 0 0 0 0 0 0 0 0 0 0);
my ($game_state, $time, $section, $level, $grade) = qw(0 0 0 0 0);
my $last_level = 0;
my $last_section = 0;
my $game_started;
my $game_ended;

open (my $fh, "<", $split_file) or goto main;
while (my $line = <$fh>) {
	chomp $line;
	my ($goldst, $splits, $splitsst, $stats) = split(/;/, $line);
	last unless $goldst && $splits && $splitsst && $stats;
	@gold_st    = split(/\s+/, $goldst);
	@splits     = split(/\s+/, $splits);
	@split_st   = split(/\s+/, $splitsst);
	@stats = split(/\s+/, $stats);
	last;
}
close $fh;

main:
$term->clrscr();
puts("Waiting for TGM to start logging");
open (my $data_fh, "<", "/dev/shm/tgm") or die "Could not open /tmp/tgm";
draw_hud();
while (my $data = <$data_fh>) {
	chomp $data;
	($game_state, $time, $section, $level, $grade) = split(/ /, $data);

	if (!$game_started && $game_state == 90) {
		$game_started = 1;
		$game_ended = 0;
		$last_level = 0;
		$last_section = 0;
		draw_hud();
	}

	next unless $game_started;

	$current_splits[ $section ] = $time;
	if ($section) {
		$current_st[ $section ] = $time - $current_splits[ $section-1 ];
	} else {
		$current_st[ $section ] = $time;
	}

	if (!$game_ended && ($game_state >= 110 || $grade[ $grade ] eq 'Gm')) {
		$game_started = 0;
		$game_ended = 1;

		draw();

		for my $i (0..$section-1) {
			if (!$gold_st[$i] || ($current_st[$i] && $current_st[$i] < $gold_st[$i])) {
				$gold_st[$i] = $current_st[$i];
			}
		}

		if ($grade[ $grade ] eq 'Gm' && (!$gold_st[9] || $current_st[9] < $gold_st[9])) {
				$gold_st[9] = $current_st[9];
		}

		if (
			$grade > $stats[0] ||
			($grade == $stats[0] && $level > $stats[1]) || 
			($grade == $stats[0] && $level == $stats[1] && $time < $stats[2])
		)	{
			@stats = ($grade, $level, $time);
			@splits = @current_splits;
			@split_st = @current_st;
		}

		save_splits();
	} else {
		draw();
	}

	$last_section = $section;
	$last_level = $level;
}
close $data_fh;

sub save_splits {
	open (my $fh, ">", $split_file) or return;
	print $fh join(" ", @gold_st), ";";
	print $fh join(" ", @splits), ";";
	print $fh join(" ", @split_st), ";";
	print $fh join(" ", @stats), "\n";
	close $fh;
}


sub draw_hud {
	$term->clrscr;
	$term->at(1,5);
	header("Time");

	for my $i (0..9) {
		$term->at($i+3,2);
		header($sec_labels[$i]);
	}
}

sub draw {
	$term->at(1,11);
	puts(fmtime($time)." (DEBUG $time $game_state)");

	for my $i (0..($section-1)) {
		$term->at(3+$i, 11);
		my $t = fmtime($current_splits[$i])."   ".fmtime($current_st[$i]);
		if ($split_st[$i] && $splits[$i]) {
			$t .= " (".fmdelta($split_st[$i],$current_st[$i]). " / ". fmdelta($splits[$i],$current_splits[$i]) .")";
		}

		if (!$gold_st[$i] || $current_st[$i] <= $gold_st[$i]) {
			gold($t);
		} elsif (
			$current_st[$i] <= $split_st[$i]
			&& $current_splits[$i] <= $splits[$i]
		) {
			good($t);
		} elsif ($current_splits[$i] <= $splits[$i]) {
			notbad($t);
		} elsif ($current_st[$i] <= $split_st[$i]) {
			notgood($t);
		} else {
			bad($t);
		}
	}

	if ($game_ended && $grade[ $grade ] ne 'Gm') {
		$term->at(3+$section, 11);
		bad(fmtime($current_splits[$section])."   ".fmtime($current_st[$section]));
	} elsif ($game_ended) {
		# !!! Gm !!!
		$term->at(3+$section, 11);
		my $t = fmtime($current_splits[$section])."   ".fmtime($current_st[$section]);
		if ($split_st[$section]) {
			$t .= " (".fmdelta($split_st[$section],$current_st[$section]).")";
		}
		if (!$split_st[$section] || $current_st[$section] < $split_st[$section]) {
			good($t);
		} else {
			bad($t);
		}
	} else {
		$term->at(3+$section, 11);
		puts(fmtime($current_splits[$section])."   ".fmtime($current_st[$section]));
	}
}

sub fmtime {
	my ($frames) = @_;
	my $t = floor($frames*5/3);
	my $dms = floor($t) % 100;
	$t = floor($t / 100);
	my $s = $t % 60;
	$t = floor($t/60);
	my $out = sprintf("%2d:%2d:%2d",$t,$s,$dms);
	$out =~ s/ /0/g;
	return $out;
}

sub fmdelta {
	my ($old, $new) = @_;
	return sprintf("%.2f", ($new-$old)*5/300);
}
sub puts {
	$term->puts(shift);
}

sub header {
	my ($title) = @_;
	$term->puts(colored($title, "bold white"));
}

sub gold {
	my ($title) = @_;
	$term->puts(colored($title, "bright_yellow"));
}

sub good {
	my ($title) = @_;
	$term->puts(colored($title, "bright_green"));
}

sub notbad {
	my ($title) = @_;
	$term->puts(colored($title, "green"));
}

sub notgood {
	my ($title) = @_;
	$term->puts(colored($title, "red"));
}

sub bad {
	my ($title) = @_;
	$term->puts(colored($title, "bright_red"));
}
