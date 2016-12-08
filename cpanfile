requires 'Class::Accessor::Lite';
requires 'perl', '5.008001';

on build => sub {
    requires 'ExtUtils::MakeMaker', '6.59';
    requires 'Test::More', '0.96';
};
