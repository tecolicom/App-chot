package App::chot;

our $VERSION = "1.01";

use v5.14;
use warnings;

use utf8;
use Encode;
use open IO => 'utf8', ':std';
use Pod::Usage;
use List::Util qw(any first);
use App::chot::Util;
use App::chot::Optex qw(detect_optex);
use Text::ParseWords qw(shellwords);

use Getopt::EX::Hashed; {
    Getopt::EX::Hashed->configure(DEFAULT => [ is => 'rw' ]);
    has one     => ' 1     ' ;
    has debug   => ' d +   ' ;
    has dryrun  => ' n     ' ;
    has info    => ' i     ' ;
    has raw     => ' r     ' ;
    has help    => ' h     ' , action => sub {
	pod2usage(-verbose => 99, -sections => [qw(SYNOPSIS)])
    } ;
    has list    => ' l +   ' ;
    has man     => ' m     ' ;
    has number  => ' N !   ' , default => 0 ;
    has version => ' v     ' , action => sub { say "Version: $VERSION"; exit } ;
    has pager   => ' p =s  ' ;
    has suffix  => '   =s  ' , default => [ qw( .pm ) ] ;
    has type    => ' t =s  ' , default => 'Command:Perl:Python:Ruby:Node' ;
    has py      => '       ' , action => sub { $_->type('Python') } ;
    has pl      => '       ' , action => sub { $_->type('Perl') } ;
    has rb      => '       ' , action => sub { $_->type('Ruby') } ;
    has nd      => '       ' , action => sub { $_->type('Node') } ;
    has bat_theme => '   %   ' ,
	default => { light => 'Coldark-Cold', dark => 'Coldark-Dark' } ;
    has skip    => '   =s@ ' ,
	default => [] ;
} no Getopt::EX::Hashed;

sub run {
    my $app = shift;
    @_ = map { utf8::is_utf8($_) ? $_ : decode('utf8', $_) } @_;
    local @ARGV = splice @_;

    use Getopt::EX::Long qw(GetOptions Configure ExConfigure);
    ExConfigure BASECLASS => [ __PACKAGE__, "Getopt::EX" ];
    Configure qw(bundling no_getopt_compat);
    $app->getopt || pod2usage();

    my $name = pop @ARGV;
    if (!defined $name) {
	if ($app->man) {
	    my $script = $ENV{CHOT_SCRIPT_PATH} // $0;
	    exec 'perldoc', $script;
	    die "perldoc: $!\n";
	}
	pod2usage();
    }
    my @option = splice @ARGV;
    my $pager = $app->pager || $ENV{'CHOT_PAGER'} || _default_pager($app);

    if ($app->info) {
	for my $type (split /:+/, $app->type) {
	    $type = _normalize_type($type);
	    my $handler = __PACKAGE__ . '::' . $type;
	    no strict 'refs';
	    eval "require $handler" or next;
	    if (defined &{"$handler\::get_info"}) {
		&{"$handler\::get_info"}($app, $name);
	    }
	}
	return 0;
    }

    my @found;
    my $found_type;
    for my $type (split /:+/, $app->type) {
	$type = _normalize_type($type);
	my $handler = __PACKAGE__ . '::' . $type;
	warn "Trying handler: $type\n" if $app->debug;
	no strict 'refs';
	if (eval "require $handler") {
	    my @paths = grep { defined } &{"$handler\::get_path"}($app, $name);
	    if (@paths) {
		warn "Found by $type: @paths\n" if $app->debug;
		push @found, @paths;
		$found_type //= $type;
		last if $app->one;
	    } else {
		warn "Not found by $type\n" if $app->debug;
	    }
	} else {
	    warn $@;
	}
    }

    if (not @found) {
	warn "$name: Nothing found.\n";
	return 1;
    }

    if (my $level = $app->list) {
	if ($level > 1) {
	    system 'ls', '-l', @found;
	} else {
	    say for @found;
	}
	return 0;
    }

    if ($app->man) {
	my $handler = __PACKAGE__ . '::' . $found_type;
	no strict 'refs';
	my @cmd = &{"$handler\::man_cmd"}($app, $name, $found[0]);
	if ($app->dryrun) {
	    say "@cmd";
	    return 0;
	}
	exec @cmd;
	die "$found_type man: $!\n";
    }

    @found = grep { !detect_optex($_) } @found;
    @found = grep {
	not &is_binary($_) or do {
	    system 'file', $_;
	    0;
	}
    } @found or return 0;

    my @pager_opts;
    if (defined $app->number) {
	my $pager_name = (shellwords($pager))[0];
	$pager_name =~ s{.*/}{};  # basename
	if ($pager_name eq 'bat') {
	    push @pager_opts, $app->number ? '--style=full' : '--style=header,grid,snip';
	} elsif ($pager_name eq 'less') {
	    push @pager_opts, '-N' if $app->number;
	}
    }
    my @cmd = (shellwords($pager), @pager_opts, @option, @found);
    if ($app->dryrun) {
	say "@cmd";
	return 0;
    }
    exec @cmd;
    die "$pager: $!\n";
}

use List::Util qw(none);

sub valid {
    my $app = shift;
    state $sub = do {
	my @re = map { qr/\Q$_\E$/ } @{$app->skip};
	sub { none { $_[0] =~ $_ } @re };
    };
    $sub->(@_);
}

sub _default_pager {
    my $app = shift;
    state $pager = do {
	my $bat = first { -x } map { "$_/bat" } split /:/, $ENV{PATH};
	if ($bat) {
	    $ENV{BAT_THEME} //= _bat_theme($app->bat_theme);
	    "$bat --force-colorization";
	} else {
	    'less';
	}
    };
}

sub _bat_theme {
    my $themes = shift;
    my $lum = eval {
	require Getopt::EX::termcolor;
	Getopt::EX::termcolor::get_luminance();
    };
    return () unless defined $lum;
    $themes->{$lum < 50 ? 'dark' : 'light'};
}

sub _normalize_type {
    my $type = shift;
    state $map = {
	command => 'Command',
	perl    => 'Perl',
	python  => 'Python',
	ruby    => 'Ruby',
	node    => 'Node',
    };
    $map->{lc $type} // ucfirst lc $type;
}

1;

__END__

=encoding utf-8

=head1 NAME

chot - Command Heuristic Omni-Tracer

=head1 SYNOPSIS

chot command/library

=head1 DESCRIPTION

Document is included in executable script.
Use `perldoc chot`.

=head1 AUTHOR

Kazumasa Utashiro

=head1 LICENSE

Copyright 1992-2026 Kazumasa Utashiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
