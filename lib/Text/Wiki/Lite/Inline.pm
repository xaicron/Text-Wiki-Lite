package Text::Wiki::Lite::Inline;

use strict;
use warnings;

sub new {
    my ($class, $code) = @_;
    bless +{ code => $code }, $class;
}

sub parse {
    my ($self, $line) = @_;
    return $self->{code}->($line);
}

1;
