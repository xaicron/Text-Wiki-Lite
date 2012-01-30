package Text::Wiki::Lite::Helper::HTML;

use strict;
use warnings;
use parent 'Exporter';
use Carp qw/croak/;
use HTML::Entities qw/encode_entities/;

our @EXPORT = qw(
    inline inline_exclusive 
    simple_block line_block hr_block
    table_block list_block default_block
    filter_block
);

sub inline {
    my ($syntax, $tag, $cb) = @_;
    $cb ||= sub { $_[0] };

    my ($start_syntax, $end_syntax);
    if (ref $syntax eq 'ARRAY') {
        ($start_syntax, $end_syntax) = map _syntax($_), @$syntax;
    }
    else {
        $start_syntax = $end_syntax = _syntax($syntax);
    }

    return sub {
        my ($c, $line) = @_;
        $line =~ s#$start_syntax((?:(?!$end_syntax).)*)$end_syntax#sprintf '<%s>%s</%1$s>', $tag, $cb->($1)#ge;
        return $line;
    };
}

sub inline_exclusive {
    my ($syntax) = @_;

    my $rule_map = {};
    my @rules;
    for (my $i = 0; $i < @$syntax; $i += 2) {
        my $regex = _syntax($syntax->[$i]);
        push @rules, $regex;
        my $callback = $syntax->[$i+1];
        unless (ref $callback eq 'CODE') {
            my $format = $callback;
            $callback = sub { sprintf $format, @_ };
        }
        $rule_map->{quotemeta $regex} = $callback;
    }
    $syntax = do {
        my $re = join '|', map {
            my $re = $_;
            $re =~ s/(?<!\\)\((?!\?)/(?:/g; # disalbed capture
            $re;
        } @rules;
        qr/($re)/;
    };

    my $find_rule = sub {
        my $matched = shift;
        for my $key (keys %$rule_map) {
            return $rule_map->{$key} if $matched =~ m#^$key$#;
        }
    };

    return sub {
        my ($c, $line) = @_;
        my @ret;
        for my $token (split $syntax, $line) {
            for my $rule (@rules) {
                if (my @matches = $token =~ /$rule/) {
                    push @ret, $find_rule->($rule)->(map encode_entities($_, q|'"<>&|), @matches);
                    goto NEXT_TOKEN;
                }
            }
            push @ret, $token;
            NEXT_TOKEN:
        }
        return join '', @ret;
    };
}

sub simple_block {
    my ($start, $end, $tag, $opts) = @_;
    $opts = {
        %{ $opts || {} },
        foldline => 1,
    };

    $start = _syntax($start);
    $end   = _syntax($end);
    my ($start_tag, $end_tag) = _make_tag($tag);

    return +{
        start => sub {
            my ($c, $line) = @_;
            my $ret = $line =~ s#^$start$#$start_tag# ? 1 : 0;
            return $line, $ret;
        },
        end => sub {
            my ($c, $line) = @_;
            my $ret = $line =~ s#^$end$#$end_tag# ? 1 : 0;
            return $line, $ret;
        },
        %$opts,
    };
}

sub filter_block {
    my ($start, $end, $tag, $filter_cb, $opts) = @_;
    $opts = {
        %{ $opts || {} },
        foldline => 1,
    };

    $start = _syntax($start);
    $end   = _syntax($end);
    my ($start_tag, $end_tag) = _make_tag($tag);

    return +{
        start => sub {
            my ($c, $line) = @_;
            my $ret = $line =~ s#^$start$#$start_tag# ? 1 : 0;
            return $line, $ret;
        },
        between => sub {
            my ($c, $line, $stash) = @_;
            $stash->{lines} ||= [];
            unless ($line =~ /^$end/) {
                push @{$stash->{lines}}, $line;
            }
            return $line;
        },
        end => sub {
            my ($c, $line, $stash) = @_;
            my $ret = $line =~ s#^$end$#$end_tag# ? 1 : 0;
            if ($ret) {
                my $lines = delete $stash->{lines};
                $c->stack->pop for 1..@$lines; # remove stacked lines
                $line = $filter_cb->($c, $lines) . $line;
            }
            return $line, $ret;
        },
        %$opts,
    };
}

sub line_block {
    my ($syntax, $tag, $opts) = @_;

    my $match;
    my ($start_tag, $end_tag) = _make_tag($tag);
    if (ref $syntax eq 'ARRAY') {
        my ($start, $end) = map _syntax($_), @$syntax;
        $match = sub {
            my $line = \$_[0];
            return $$line =~ s#^$start (.*) $end$#$start_tag$1$end_tag# ? 1 : 0;
        };
    }
    else {
        $syntax = _syntax($syntax);
        $match = sub {
            my $line = \$_[0];
            return $$line =~ s#^$syntax (.*)#$start_tag$1$end_tag# ? 1 : 0;
        };
    }

    return {
        start => sub {
            my ($c, $line) = @_;
            my $ret = $match->($line);
            return $line, $ret;
        },
        end => sub {
            my ($c, $line) = @_;
            return $line, 1;
        },
        %{ $opts || {} },
    };
}

sub hr_block {
    my ($syntax, $tag) = @_;
    $syntax = _syntax($syntax);
    return {
        start => sub {
            my ($c, $line) = @_;
            my $ret = $line =~ s#^$syntax$#$tag# ? 1 : 0;
            return $line, $ret;
        },
        end => sub {
            my ($c, $line) = @_;
            return $line, 1;
        },
    };
}

sub table_block {
    my ($syntax, $opts) = @_;
    $opts = {
        %{ $opts || {} },
        foldline => 1,
    };

    my $class = $opts->{class} || {};

    my $th_syntax;
    if (ref $syntax eq 'ARRAY') {
        ($syntax, $th_syntax) = map _syntax($_), @$syntax;
    }
    else {
        $syntax = _syntax($syntax);
    }

    my $replacer = sub {
        my $matched = shift;
        $matched =~ s/^\s+|\s+$//g;
        my $result;
        if ($th_syntax && $matched =~ s/^$th_syntax//) {
            $result = _class('th', $class->{th})."$matched</th>";
        }
        else {
            $result = _class('td', $class->{td})."$matched</td>";
        }
        return "$result\n";
    };

    my $check   = qr/^($syntax.*)$syntax$/;
    my $prepare = qr/$syntax((?:(?!$syntax).)*)/;

    return {
        start => sub {
            my ($c, $line, $stash) = @_;
            my $ret;
            if ($line =~ s/$check/$1/) {
                $line =~ s#$prepare#$replacer->($1)#ge;
                $line = _class('table', $class->{table})."\n"._class('tr', $class->{tr})."\n$line</tr>";
                $ret = 1;
            }
            return $line, $ret;
        },
        between => sub {
            my ($c, $line, $stash) = @_;
            if ($line =~ s/$check/$1/) {
                $line =~ s#$prepare#$replacer->($1)#ge;
                $line = _class('tr', $class->{tr}) ."\n$line</tr>";
                $stash->{finished} = 0;
            }
            elsif ($c->parent_cb->($line)) {
                $stash->{finished} = 1;
            }
            else {
                $stash->{finished} = 1;
            }
            return $line;
        },
        end => sub {
            my ($c, $line, $stash) = @_;
            my $ret = $stash->{finished} ? 1 : 0;
            $line = '</table>' if $ret;
            return $line, $ret;
        },
        %$opts,
    };
}

sub list_block {
    my ($syntax, $tag, $opts) = @_;

    my ($s_tag, $e_tag) = _make_tag($tag);

    my $start_tag_map = {};
    my @regexp;
    for (my $i = 0; $i < @$syntax; $i += 2) {
        my $regex = _syntax($syntax->[$i]);
        push @regexp, $regex;
        $start_tag_map->{$regex} = $syntax->[$i+1];
    }
    $syntax = join '|', @regexp;

    my $find_start_tag = sub {
        my $matched = shift;
        for my $key (keys %$start_tag_map) {
            return $start_tag_map->{$key} if $matched =~ m#^$key$#;
        }
    };

    return {
        start => sub {
            my ($c, $line, $stash) = @_;
            my $ret;
            if ($line =~ s/^(\s*)($syntax) (.*)/$3/) {
                $stash->{indent} = length $1 || 0;
                my $start_tag = $stash->{start_tag} = $find_start_tag->($2);
                $line = "<$start_tag>\n${s_tag}${line}${e_tag}";
                $ret = 1;
            }
            return $line, $ret;
        },
        between => sub {
            my ($c, $line, $stash) = @_;
            if ($line =~ /^(\s*)($syntax) (.*)/) {
                my $current_indent = length $1 || 0;
                my $start_tag = $find_start_tag->($2);
                my $text = $3;
                if ($stash->{indent} < $current_indent) {
                    $line = "<$start_tag>\n${s_tag}${text}${e_tag}";
                    push @{$stash->{_indent}}, $stash->{indent};
                    push @{$stash->{_start_tag}}, $start_tag;
                    $stash->{indent} = $current_indent;
                }
                elsif ($stash->{indent} > $current_indent) {
                    my @end_tags;
                    while (defined (my $indent = $stash->{_indent}->[-1])) {
                        if ($indent >= $current_indent) {
                            push @end_tags, pop @{$stash->{_start_tag}};
                            pop @{$stash->{_indent}};
                        }
                        else {
                            last;
                        }
                    }
                    my $end_tag = join '', map { "</$_>\n" } @end_tags;
                    $line = "${end_tag}${s_tag}${text}${e_tag}";
                    $stash->{indent} = $current_indent;
                }
                else {
                    $line = "${s_tag}${text}${e_tag}";
                }
            }
            else {
                $stash->{finished} = 1;
            }
            return $line;
        },
        end => sub {
            my ($c, $line, $stash) = @_;
            my $ret = 0;
            if ($stash->{finished}) {
                my @end_tags = ($stash->{start_tag});
                while (defined (my $indent = $stash->{_indent}->[-1])) {
                    push @end_tags, pop @{$stash->{_start_tag}};
                    pop @{$stash->{_indent}};
                }
                my $end_tag = join "\n", map { "</$_>" } @end_tags;
                $stash->{__NEXT_LINE__} = $line;
                $line = $end_tag;
                $ret = 1;
            }
            return $line, $ret;
        },
        foldline => 1,
        inline => 1,
        %{ $opts || {} },
    };
}

sub default_block {
    my ($tag, $line_break, $opts) = @_;
    my ($start_tag, $end_tag) = _make_tag($tag);

    return {
        start => sub {
            my ($c, $line, $stash) = @_;
            my $ret = 0;
            unless ($line =~ /^\s*$/) {
                $line = "$start_tag\n$line";
                $stash->{first} = 1;
                $ret = 1;
            }
            return $line, $ret;
        },
        between => sub {
            my ($c, $line, $stash) = @_;
            if ($stash->{first}) {
                delete $stash->{first};
            }
            elsif ($line =~ /^\s*$/) {
                $stash->{finished} = 1;
            }
            else {
                if ($c->parent_cb->($line)) {
                    $stash->{finished} = 1;
                }
                elsif ($line_break) {
                    $line = "<br />$line";
                }
            }
            return $line;
        },
        end => sub {
            my ($c, $line, $stash) = @_;
            my $ret;
            if ($stash->{finished}) {
                $line = "$end_tag";
                $ret = 1;
            }
            return $line, $ret;
        },
        %{ $opts || {} },
    };
}

sub _make_tag {
    my $tag = shift;
    my ($start_tag, $end_tag);
    if (ref $tag eq 'ARRAY') {
        ($start_tag, $end_tag) = @$tag;
    }
    else {
        $start_tag = "<$tag>";
        $end_tag   = "</$tag>";
    }
    return $start_tag, $end_tag;
}

sub _syntax {
    my $syntax = shift;
    return ref $syntax eq 'Regexp' ? $$syntax : quotemeta $syntax;
}

sub _class {
    my ($tag, $class) = @_;
    sprintf '<%s%s>', $tag, $class ? qq{ class="$class"} : '';
}

1;
