package Text::Wiki::Lite::Block;

use strict;
use warnings;

sub new {
    my ($class, $rule) = @_;
    bless +{ %$rule }, $class;
}

sub start {
    my ($self, $line, @args) = @_;
    $self->{start}->($self, $line, @args);
}

sub between {
    my ($self, $line, @args) = @_;
    $self->{between}->($self, $line, @args);
}

sub end {
    my ($self, $line, @args) = @_;
    $self->{end}->($self, $line, @args);
}

sub parent_cb {
    my $self = shift;
    $self->{parent_cb} || sub {};
}

sub set_parent_cb {
    my ($self, $cb) = @_;
    $self->{parent_cb} = $cb;
}

sub remove_parent_cb {
    my $self = shift;
    delete $self->{parent_cb};
}

sub wiki {
    shift->{wiki};
}

sub stack {
    shift->{wiki}->out;
}

sub ident {
    shift->{ident};
}

sub inline {
    shift->{inline};
}

sub escape {
    shift->{escape};
}

sub nest {
    shift->{nest};
}

sub foldline {
    shift->{foldline};
}

sub default_block {
    shift->{default_block};
}

sub merge_pre {
    shift->{merge_pre};
}

sub is_default {
    shift->{is_default};
}

1;
