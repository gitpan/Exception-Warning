#!/usr/bin/perl -c

package Exception::Warning;
use 5.006;
our $VERSION = 0.02;

=head1 NAME

Exception::Warning - Convert simple warn into real exception object

=head1 SYNOPSIS

  # Convert warn into exception and throw it immediately
  use Exception::Warning '%SIG' => 'die';
  eval { warn "Boom!"; };
  print ref $@;        # "Exception::Warning"
  print $@->warning;   # "Boom!"

  # Convert warn into exception without die
  use Exception::Warning '%SIG' => 'warn', verbosity => 4;
  warn "Boom!";   # dumps full stack trace

  # Can be used in local scope only
  use Exception::Warning;
  {
      local $SIG{__WARN__} = \&Exception::Warning::__WARN__;
      warn "Boom!";   # warn via exception
  }
  warn "Boom!";       # standard warn

  # Run Perl with verbose warnings
  perl -MException::Warning=%SIG,warn,verbosity=>3 script.pl

  # Run Perl which dies on first warning
  perl -MException::Warning=%SIG,die,verbosity=>3 script.pl

  # Run Perl which ignores any warnings
  perl -MException::Warning=%SIG,warn,verbosity=>0 script.pl

=head1 DESCRIPTION

This class extends standard L<Exception::Base> and converts warning into
real exception object.  The warning message is stored in I<warning>
attribute.

=for readme stop

=cut


use strict;
use warnings;


# Extend Exception::Base class
use Exception::Base 0.19;
use base 'Exception::Base';


# List of class fields (name => {is=>ro|rw, default=>value})
use constant ATTRS => {
    %{ Exception::Base->ATTRS },     # SUPER::ATTRS
    stringify_attributes => { default => [ 'message', 'warning' ] },
    default_attribute => { default => 'warning' },
    message           => { is => 'rw', default => 'Unknown warning' },
    warning           => { is => 'ro' },
};


# Handle %SIG tag
sub import {
    my $pkg = shift;

    my @params;

    while (defined $_[0]) {
        my $name = shift @_;
        if ($name eq '%SIG') {
            my $type = 'warn';
            if (defined $_[0] and $_[0] =~ /^(die|warn)$/) {
                $type = shift @_;
            }
            # Handle warn hook
            if ($type eq 'warn') {
                # is 'warn'
                $SIG{__WARN__} = \&__WARN__;
            }
            else {
                # must be 'die'
                $SIG{__WARN__} = \&__DIE__;
            }
        }
        else {
            # Other parameters goes to SUPER::import
            push @params, $name;
            push @params, shift @_ if defined $_[0] and ref $_[0] eq 'HASH';
        }
    }

    if (@params) {
        return $pkg->SUPER::import(@params);
    }

    return 1;
}


# Unexport try/catch
sub unimport {
    my $pkg = shift;
    my $callpkg = caller;

    while (my $name = shift @_) {
        if ($name eq '%SIG') {
            # Undef die hook
            $SIG{__WARN__} = '';
        }
    }

    return 1;
}


# Warning hook with die
sub __DIE__ {
    if (not ref $_[0]) {
        # Do not recurse on Exception::Died & Exception::Warning
        die $_[0] if $_[0] =~ /^Exception::(Died|Warning): /;

        # Simple warn: recover warning message
        my $message = $_[0];
        $message =~ s/\t\.\.\.caught at (?!.*\bat\b.*).* line \d+( thread \d+)?\.\n?$//s;
        while ($message =~ s/\t\.\.\.propagated at (?!.*\bat\b.*).* line \d+( thread \d+)?\.\n$//s) { }
        $message =~ s/( at (?!.*\bat\b.*).* line \d+( thread \d+)?\.)?\n$//s;

        my $e = __PACKAGE__->new;
        $e->{warning} = $message;
        die $e;
    }
    # Otherwise: throw unchanged exception
    die $_[0];
}


# Warning hook with warn
sub __WARN__ {
    if (not ref $_[0]) {
        # Some optimalization
        return if __PACKAGE__->ATTRS->{verbosity}->{default} == 0;

        # Simple warn: recover warning message
        my $message = $_[0];
        $message =~ s/\t\.\.\.caught at (?!.*\bat\b.*).* line \d+( thread \d+)?\.$//s;
        while ($message =~ s/\t\.\.\.propagated at (?!.*\bat\b.*).* line \d+( thread \d+)?\.\n$//s) { }
        $message =~ s/( at (?!.*\bat\b.*).* line \d+( thread \d+)?\.)?\n$//s;

        my $e = __PACKAGE__->new;
        $e->{warning} = $message;
        warn $e;
    }
    else {
        # Otherwise: throw unchanged exception
        warn $_[0];
    }
}


# Module initialization
sub __init {
    __PACKAGE__->_make_accessors;
}


__init;


1;


__END__

=begin umlwiki

= Class Diagram =

[                         <<exception>>
                        Exception::Warning
 --------------------------------------------------------------
 +message : Str = "Unknown warning"                       {new}
 +warning : Str
 #default_attribute : Str = "warning"
 #stringify_attributes : ArrayRef[Str] = ["message", "warning"]
 --------------------------------------------------------------
 #_collect_system_data()
 <<utility>> -__DIE__()
 <<utility>> -__WARN__()
 <<constant>> +ATTRS() : HashRef                               ]

[Exception::Warning] ---|> [Exception::Base]

=end umlwiki

=head1 BASE CLASSES

=over

=item *

L<Exception::Base>

=back

=head1 IMPORTS

=over

=item use Exception::Died '%SIG';

=item use Exception::Died '%SIG' => 'warn';

Changes B<$SIG{__WARN__}> hook to B<Exception::Died::__WARN__> function.

=item use Exception::Died '%SIG' => 'die';

Changes B<$SIG{__WARN__}> hook to B<Exception::Died::__DIE__> function.

=back

=head1 CONSTANTS

=over

=item ATTRS

Declaration of class attributes as reference to hash.

See L<Exception::Base> for details.

=back

=head1 ATTRIBUTES

This class provides new attributes.  See L<Exception::Base> for other
descriptions.

=over

=item message (rw, default: 'Unknown warning')

Contains the message of the exception.  This class overrides the default value
from L<Exception::Base> class.

=item warning (ro)

Contains the message which is set by B<$SIG{__WARN__}> hook.

=item stringify_attributes (default: ['message', 'eval_error'])

Meta-attribute contains the format of string representation of exception
object.  This class overrides the default value from L<Exception::Base>
class.

=item default_attribute (default: 'eval_error')

Meta-attribute contains the name of the default attribute.  This class
overrides the default value from L<Exception::Base> class.

=back

=head1 PRIVATE FUNCTIONS

=over

=item __WARN__

This is a hook function for $SIG{__WARN__}.  It converts the warning into
exception object which is immediately stringify to scalar and printed with
B<warn> core function.  This hook can be enabled with pragma:

  use Exception::Died '%SIG' => 'warn';

or manually, i.e. for local scope:

  local $SIG{__WARN__} = \&Exception::Died::__WARN__;

=item __DIE__

This is a hook function for $SIG{__DIE__}.  It converts the warning into
exception object which is immediately thrown.  This hook can be enabled with
pragma:

  use Exception::Died '%SIG' => 'die';

or manually, i.e. for local scope:

  local $SIG{__WARN__} = \&Exception::Died::__DIE__;

=back

=head1 PERFORMANCE

The B<Exception::Warning> module can change B<$SIG{__WARN__}> hook.  It costs
a speed for simple warn operation.  It was tested against unhooked warn.

  -------------------------------------------------------
  | Module                              |         run/s |
  -------------------------------------------------------
  | undef $SIG{__WARN__}                |      276243/s |
  -------------------------------------------------------
  | $SIG{__WARN__} = sub { }            |      188215/s |
  -------------------------------------------------------
  | Exception::Warning '%SIG'           |        1997/s |
  -------------------------------------------------------
  | Exception::Warning '%SIG', verb.=>0 |      152348/s |
  -------------------------------------------------------

It means that B<Exception::Warning> is significally slower than simple warn.
It is usually used only for debugging purposes, so it shouldn't be an
important problem.

=head1 SEE ALSO

L<Exception::Base>.

=head1 BUGS

If you find the bug, please report it.

=for readme continue

=head1 AUTHOR

Piotr Roszatycki E<lt>dexter@debian.orgE<gt>

=head1 LICENSE

Copyright (C) 2008 by Piotr Roszatycki E<lt>dexter@debian.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>
