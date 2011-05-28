package Text::Wiki::Lite::Block;

use strict;
use warnings;

sub new {
    my ($class, $rule) = @_;
    bless +{ %$rule }, $class;
}

sub start {
    my ($self, $line, @args) = @_;
    $self->{start}->($line, @args);
}

sub between {
    my ($self, $line, @args) = @_;
    $self->{between}->($line, @args);
}

sub end {
    my ($self, $line, @args) = @_;
    $self->{end}->($line, @args);
}

sub enabled_inline {
    shift->{enabled_inline};
}

sub enabled_escape {
    shift->{enabled_escape};
}

sub enabled_nest {
    shift->{enabled_nest};
}

sub foldline {
    shift->{foldline};
}

sub enabled_default_block {
    shift->{enabled_default_block};
}

sub merge_pre {
    shift->{merge_pre};
}

sub is_default {
    shift->{is_default};
}

1;
