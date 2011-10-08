package Text::Wiki::Lite::Inline;

use strict;
use warnings;

sub new {
    my ($class, $ident, $code) = @_;
    bless +{
        ident => $ident,
        code  => $code,
    }, $class;
}

sub ident {
    shift->{ident};
}

sub parse {
    my ($self, $line) = @_;
    return $self->{code}->($self, $line);
}

sub wiki {
    shift->{wiki};
}

sub output {
    shift->{wiki}->output;
}

1;
