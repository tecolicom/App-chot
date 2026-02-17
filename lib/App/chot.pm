package App::chot;

our $VERSION = "1.04";

use v5.14;
use warnings;

use utf8;
use Encode;
use open IO => 'utf8', ':std';
use Pod::Usage;
use List::Util qw(any first);
use App::chot::Util;
use App::chot::Optex qw(detect_optex);
use App::chot::Found;
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
    has deref   => ' L     ' ;
    has man     => ' m     ' ;
    has number  => ' N !   ' , default => 0 ;
    has version => ' v     ' , action => sub { say "Version: $VERSION"; exit } ;
    has pager   => ' p =s  ' ;
    has column  => ' C :i  ' ;
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

    #
    # Load and instantiate all finder objects once.
    # Each finder gets the same $app, $name, and shared $found,
    # and is reused across -i, main, and -m dispatch below.
    #
    my $found = App::chot::Found->new;
    my @finders;  # [ [$type, $finder_obj], ... ]
    for my $type (split /:+/, $app->type) {
	$type = _normalize_type($type);
	my $class = __PACKAGE__ . '::' . $type;
	eval "require $class" or do { warn $@ if $app->debug; next };
	push @finders, [
	    $type,
	    $class->new(app => $app, name => $name, found => $found),
	];
    }

    # -i mode: print trace/resolution info and exit
    if ($app->info) {
	for my $pair (@finders) {
	    my($type, $h) = @$pair;
	    $h->get_info if $h->can('get_info');
	}
	return 0;
    }

    #
    # Main discovery loop: try each finder in order.
    # Results are accumulated in $found so that later finders
    # (e.g., Python) can use paths found by earlier ones (e.g., Command).
    #
    my @found;
    for my $pair (@finders) {
	my($type, $h) = @$pair;
	warn "Trying finder: $type\n" if $app->debug;
	my @paths = grep { defined } $h->get_path;
	if (@paths) {
	    warn "Found by $type: @paths\n" if $app->debug;
	    push @found, @paths;
	    $found->add($type, @paths);
	    last if $app->one;
	} else {
	    warn "Not found by $type\n" if $app->debug;
	}
    }

    if (not @found) {
	warn "$name: Nothing found.\n";
	return 1;
    }

    if (my $level = $app->list) {
	if ($level > 1) {
	    system 'ls', ($app->deref ? '-lL' : '-l'), @found;
	} else {
	    say for @found;
	}
	return 0;
    }

    #
    # -m mode: try each finder's man_cmd in the order results were found.
    # Finders return empty list to skip, allowing fallback to the next.
    # Uses exec (not system) to preserve terminal/signal handling.
    #
    if ($app->man) {
	my %finder_by_type = map { @$_ } @finders;
	my $tried;
	for my $type (@{$found->types}) {
	    my $h = $finder_by_type{$type} or next;
	    next unless $h->can('man_cmd');
	    my @cmd = $h->man_cmd or next;
	    if ($app->dryrun) {
		say "@cmd";
		$tried++;
		next;
	    }
	    exec @cmd;
	    die "$type man: $!\n";
	}
	return $tried ? 0 : 1;
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
    if (defined(my $col = $app->column)) {
	@cmd = grep { $_ ne '--force-colorization' } @cmd;
	unshift @cmd, 'nup', '-e', ($col ? ("-C$col") : ());
    }
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
