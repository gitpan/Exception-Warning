package Exception::WarningTest;

use strict;
use warnings;

use base 'Test::Unit::TestCase';

use Exception::Warning '%SIG';

sub test___isa {
    my $self = shift;
    my $obj = Exception::Warning->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("Exception::Warning"), '$obj->isa("Exception::Warning")');
    $self->assert($obj->isa("Exception::Base"), '$obj->isa("Exception::Base")');
}

sub test_attribute {
    my $self = shift;
    local $@;
    my $obj = Exception::Warning->new(message=>'Message');
    $self->assert_equals('Message', $obj->{message});
    $self->assert_equals('', $obj->{warning});
}

sub test_accessor {
    my $self = shift;
    my $obj = Exception::Warning->new(message=>'Message');
    $self->assert_equals('Message', $obj->message);
    $self->assert_equals('New message', $obj->message = 'New message');
    $self->assert_equals('New message', $obj->message);
    $self->assert_null($obj->warning);
    eval { $self->assert_equals(0, $obj->warning = 123) };
    $self->assert_matches(qr/modify non-lvalue subroutine call/, $@);
}

sub test_warn_die {
    my $self = shift;

    local $SIG{__WARN__} = \&Exception::Warning::__DIE__;

    eval { warn "Boom1"; };

    my $obj1 = $@;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("Exception::Warning"), '$obj1->isa("Exception::Warning")');
    $self->assert_null($obj1->{message});
    $self->assert_equals('Boom1', $obj1->{warning});

    eval { warn "Boom2\n"; };

    my $obj2 = $@;
    $self->assert_not_null($obj2);
    $self->assert($obj2->isa("Exception::Warning"), '$obj2->isa("Exception::Warning")');
    $self->assert_null($obj2->{message});
    $self->assert_equals('Boom2', $obj2->{warning});

    eval { $@ = "Boom3\n"; warn; };

    my $obj3 = $@;
    $self->assert_not_null($obj3);
    $self->assert($obj3->isa("Exception::Warning"), '$obj3->isa("Exception::Warning")');
    $self->assert_null($obj3->{message});
    $self->assert_equals('Boom3', $obj3->{warning});

    eval { $@ = "Boom4\n\t...propagated at -e line 1.\n"; warn; };

    my $obj4 = $@;
    $self->assert_not_null($obj4);
    $self->assert($obj4->isa("Exception::Warning"), '$obj4->isa("Exception::Warning")');
    $self->assert_null($obj4->{message});
    $self->assert_equals('Boom4', $obj4->{warning});

    eval { $@ = "Boom5\n\t...propagated at -e line 1.\n\t...propagated at -e line 1.\n"; warn; };

    my $obj5 = $@;
    $self->assert_not_null($obj5);
    $self->assert($obj5->isa("Exception::Warning"), '$obj5->isa("Exception::Warning")');
    $self->assert_null($obj5->{message});
    $self->assert_equals('Boom5', $obj5->{warning});
}

sub test_warn_warn {
    my $self = shift;

    my $default_verbosity = Exception::Warning->ATTRS->{verbosity}->{default};
    $self->assert_not_null($default_verbosity);
    Exception::Warning->import(verbosity => 0);
    $self->assert_equals(0, Exception::Warning->ATTRS->{verbosity}->{default});

    local $SIG{__WARN__} = \&Exception::Warning::__WARN__;
    eval {
        eval { warn "Boom1"; };

        $self->assert_equals('', $@);
    };

    Exception::Warning->import(verbosity => $default_verbosity);
    die if $@;
}

sub test_stringify {
    my $self = shift;

    my $obj = Exception::Warning->new(message=>'Stringify');

    $self->assert_not_null($obj);
    $self->assert($obj->isa("Exception::Warning"), '$obj->isa("Exception::Warning")');
    $self->assert($obj->isa("Exception::Base"), '$obj->isa("Exception::Base")');
    $self->assert_equals('', $obj->stringify(0));
    $self->assert_equals("Stringify\n", $obj->stringify(1));
    $self->assert_matches(qr/Stringify at .* line \d+.\n/s, $obj->stringify(2));
    $self->assert_matches(qr/Exception::Warning: Stringify at .* line \d+\n/s, $obj->stringify(3));
    $self->assert_equals("Message\n", $obj->stringify(1, "Message"));
    $self->assert_equals("Unknown warning\n", $obj->stringify(1, ""));

    $obj->{warning} = 'Warning';
    $self->assert_equals('', $obj->stringify(0));
    $self->assert_equals("Stringify: Warning\n", $obj->stringify(1));
    $self->assert_matches(qr/Stringify: Warning at .* line \d+.\n/s, $obj->stringify(2));
    $self->assert_matches(qr/Exception::Warning: Stringify: Warning at .* line \d+\n/s, $obj->stringify(3));
    $self->assert_equals("Message\n", $obj->stringify(1, "Message"));
    $self->assert_equals("Unknown warning\n", $obj->stringify(1, ""));

    $self->assert_equals(1, $obj->{defaults}->{verbosity} = 1);
    $self->assert_equals(1, $obj->{defaults}->{verbosity});
    $self->assert_equals("Stringify: Warning\n", $obj->stringify);
    $self->assert_not_null($obj->{defaults}->{verbosity});
    $obj->{defaults}->{verbosity} = Exception::Warning->ATTRS->{verbosity}->{default};
    $self->assert_equals(1, $obj->{verbosity} = 1);
    $self->assert_equals("Stringify: Warning\n", $obj->stringify);

    $self->assert_equals("Stringify: Warning\n", "$obj");
}

sub test_import_keywords {
    my $self = shift;

    local $SIG{__DIE__};

    no warnings 'reserved';
    eval 'Exception::Warning->import(qw<%SIG>);';
    $self->assert_equals('CODE', ref $SIG{__WARN__});
    $self->assert_str_equals(\&Exception::Warning::__WARN__, $SIG{__WARN__});

    eval 'Exception::Warning->unimport(qw<%SIG>);';
    $self->assert_equals('', ref $SIG{__WARN__});

    eval 'Exception::Warning->import(qw<%SIG> => "warn");';
    $self->assert_equals('CODE', ref $SIG{__WARN__});
    $self->assert_str_equals(\&Exception::Warning::__WARN__, $SIG{__WARN__});

    eval 'Exception::Warning->import(qw<%SIG> => "die");';
    $self->assert_equals('CODE', ref $SIG{__WARN__});
    $self->assert_str_equals(\&Exception::Warning::__DIE__, $SIG{__WARN__});

    eval 'Exception::Warning->unimport(qw<%SIG>);';
    $self->assert_equals('', ref $SIG{__WARN__});

    eval 'Exception::Warning->import(qw<Exception::Warning::test::Import1>);';
    $self->assert_matches(qr/can only be created with/, "$@");

    eval 'Exception::Warning->import(qw<Exception::Warning::test::Import1> => { has => "attr" });';
    $self->assert_matches(qr/can only be created with/, "$@");

    eval 'Exception::Warning->import(qw<Exception::Warning::test::Import1> => "%SIG");';
    $self->assert_matches(qr/can only be created with/, "$@");
    $self->assert_equals('CODE', ref $SIG{__WARN__});

    eval 'Exception::Warning->unimport(qw<nothing>);';
    $self->assert_equals('CODE', ref $SIG{__WARN__});
}

1;
