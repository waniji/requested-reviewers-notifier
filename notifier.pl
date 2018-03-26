#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use JSON qw/decode_json/;
use Encode qw/encode_utf8/;
use Net::GitHub;
use WebService::Slack::WebApi;

sub main {
    my $argv = shift;

    my $options = parse_options($argv);
    my $message = generate_message($options->{github_repos}, $options->{github_token});
    return unless defined $message;

    notify_slack($options->{slack_token}, $options->{slack_channel}, $message);
}

sub parse_options {
    my $argv = shift;

    my $p = Getopt::Long::Parser->new(
        config => [ "posix_default", "no_ignore_case" ]
    );

    $p->getoptionsfromarray($argv, \my %options, qw/
        config=s
        github_token=s
        github_repos=s
        slack_token=s
        slack_channel=s
    /) or die;
    # TODO: use pod2usage

    my $config = {};
    if ($options{config}) {
        open (my $fh, '<', $options{config}) || die "cannot open $!";
        $config = decode_json do {
            local $/ = undef;
            <$fh>;
        };
    }

    if ($options{github_repos}) {
        $options{github_repos} = [ split(",", $options{github_repos}) ];
    }

    $options{github_repos} //= $config->{github_repos};
    $options{github_token} //= $config->{github_token};
    $options{slack_token} //= $config->{slack_token};
    $options{slack_channel} //= $config->{slack_channel};

    return \%options;
}

sub generate_pull_request_message {
    my ($account, $repo, $pull, $reviewers) = @_;
    return sprintf(
        "[%s] %s %s %s :point_right: %s",
        $pull->{created_at},
        sprintf("<https://github.com/%s/%s/pull/%d|%s/%s#%d>", $account, $repo, $pull->{number}, $account, $repo, $pull->{number}),
        sprintf(":%s:", $pull->{user}->{login}),
        encode_utf8($pull->{title}),
        join(" ", @$reviewers),
    );
}

sub generate_reviewer_count_message {
    my $review_count = shift;

    my @sorted = sort { $review_count->{$b} <=> $review_count->{$a} } keys %$review_count;
    return join(",", map { sprintf("%s => %d", $_, $review_count->{$_}) } @sorted);
}

sub generate_message {
    my ($github_repos, $github_token) = @_;

    my $github = Net::GitHub->new(access_token => $github_token);
    my $pull_request = $github->pull_request;
    my %review_count;
    my @result;
    for my $github_repo (@$github_repos) {
        my ($account, $repo) = split("/", $github_repo);
        $pull_request->set_default_user_repo($account, $repo);
        my @pulls = $pull_request->pulls( { state => 'open' } );
        for my $pull (@pulls) {
            my $res = $pull_request->reviewers($pull->{number})->{users};
            next unless scalar(@$res);
            my @reviewers = map { sprintf ":%s:", $_->{login} } @$res;
            $review_count{$_}++ for @reviewers;
            push @result, generate_pull_request_message($account, $repo, $pull, \@reviewers);
        }
    }

    return unless scalar(@result);

    push @result, generate_reviewer_count_message(\%review_count);

    return join("\n", @result);
}

sub notify_slack {
    my ($slack_token, $slack_channel, $message) = @_;

    my $slack = WebService::Slack::WebApi->new(token => $slack_token);
    my $posted_message = $slack->chat->post_message(
        channel => $slack_channel,
        username => "Requested Reviewers",
        text => $message,
        icon_emoji => ":github:",
    );
}

main(\@ARGV);
