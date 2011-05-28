package Text::Wiki::Lite::Output;

use strict;
use warnings;

sub new {
    my ($class) = @_;
    bless [], $class;
}

sub push {
    my $self = CORE::shift;
    CORE::push @$self, @_;
}

sub pop {
    my $self = CORE::shift;
    CORE::pop @$self;
}

sub shift {
    my $self = CORE::shift;
    CORE::shift @$self;
}

sub unshift {
    my $self = CORE::shift;
    CORE::unshift @$self, @_;
}

sub join {
    my ($self, $expr) = @_;
    return CORE::join $expr, @$self,
}

1;
