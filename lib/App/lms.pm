package App::lms;

our $VERSION = "0.12";

use v5.14;
use warnings;

use utf8;
use Encode;
use Data::Dumper;
use open IO => 'utf8', ':std';
use Pod::Usage;
use List::Util qw(any first);
use App::lms::Util;
use Text::ParseWords qw(shellwords);

use Getopt::EX::Hashed; {
    Getopt::EX::Hashed->configure(DEFAULT => [ is => 'rw' ]);
    has debug   => '       ' ;
    has help    => ' h     ' , action => sub { pod2usage(-verbose => 1) } ;
    has list    => ' l +   ' ;
    has man     => ' m     ' ;
    has version => ' v     ' , action => sub { say "Version: $VERSION"; exit } ;
    has pager   => ' p =s  ' ;
    has suffix  => '   =s  ' , default => [ qw( .pm ) ] ;
    has type    => ' t =s  ' , default => 'Command:Perl:Python' ;
    has skip    => '   =s@ ' ,
	default => [ $ENV{OPTEX_BINDIR} || ".optex.d/bin" ] ;
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
	    my $script = $ENV{LMS_SCRIPT_PATH} // $0;
	    exec 'perldoc', $script;
	    die "perldoc: $!\n";
	}
	pod2usage();
    }
    my @option = splice @ARGV;
    my $pager = $app->pager || $ENV{'PAGER'} || 'less';

    my @found;
    my $found_type;
    for my $type (split /:+/, $app->type) {
	my $handler = __PACKAGE__ . '::' . $type;
	no strict 'refs';
	if (eval "require $handler") {
	    my @paths = grep { defined } &{"$handler\::get_path"}($app, $name);
	    if (@paths) {
		@found = @paths;
		$found_type = $type;
		last;
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
	if ($found_type eq 'Perl') {
	    exec 'perldoc', '-F', $found[0];
	} elsif ($found_type eq 'Python') {
	    exec 'python3', '-m', 'pydoc', $name;
	} elsif ($found_type eq 'Command') {
	    exec 'man', $name;
	}
	die "$found_type man: $!\n";
    }

    @found = grep {
	not &is_binary($_) or do {
	    system 'file', $_;
	    0;
	}
    } @found or return 0;

    exec shellwords($pager), @option, @found;
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

1;

__END__

=encoding utf-8

=head1 NAME

lms - Let Me See command

=head1 SYNOPSIS

lms command/library

=head1 DESCRIPTION

Document is included in executable script.
Use `perldoc lms`.

=head1 AUTHOR

Kazumasa Utashiro

=head1 LICENSE

Copyright 1992-2021 Kazumasa Utashiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
