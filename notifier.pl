#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use JSON qw/decode_json/;
use Encode qw/encode_utf8/;
use Net::GitHub;
use WebService::Slack::WebApi;

my $p = Getopt::Long::Parser->new(
    config => [ "posix_default", "no_ignore_case" ]
);

$p->getoptionsfromarray(\@ARGV, \my %opt, qw/
    config=s
    github_token=s
    github_repos=s
    slack_token=s
    slack_channel=s
/) or die;
# TODO: use pod2usage

my $config = {};
if ($opt{config}) {
    open (my $fh, '<', $opt{config}) || die "cannot open $!";
    $config = decode_json do {
        local $/ = undef;
        <$fh>;
    };
}

my @github_repos = do {
    if ($config->{github_repos}) {
        @{ $config->{github_repos} };
    }
    elsif ($opt{github_repos}) {
        split(",", $opt{github_repos});
    }
};
my $github_token = $config->{github_token} // $opt{github_token};
my $slack_token = $config->{slack_token} // $opt{slack_token};
my $slack_channel = $config->{slack_channel} // $opt{slack_channel};

my $github = Net::GitHub->new(access_token => $github_token);
my $pull_request = $github->pull_request;
my %review_count;
my @result;
for my $github_repo (@github_repos) {
    my ($account, $repo) = split("/", $github_repo);
    $pull_request->set_default_user_repo($account, $repo);
    my @pulls = $pull_request->pulls( { state => 'open' } );
    for my $pull (@pulls) {
        my $res = $pull_request->reviewers($pull->{number})->{users};
        next unless scalar(@$res);
        my @reviewers = map { sprintf ":%s:", $_->{login} } @$res;
        $review_count{$_}++ for @reviewers;
        push @result, sprintf(
            "[%s] %s %s %s :point_right: %s",
            $pull->{created_at},
            sprintf("<https://github.com/%s/%s/pull/%d|%s/%s#%d>", $account, $repo, $pull->{number}, $account, $repo, $pull->{number}),
            sprintf(":%s:", $pull->{user}->{login}),
            encode_utf8($pull->{title}),
            join(" ", @reviewers),
        );
    }
}

exit unless scalar(@result);

push @result, join(", ", map { sprintf("%s => %d", $_, $review_count{$_}) } sort { $review_count{$b} <=> $review_count{$a} } keys %review_count);

my $slack = WebService::Slack::WebApi->new(token => $slack_token);
my $posted_message = $slack->chat->post_message(
    channel => $slack_channel,
    username => "Requested Reviewers",
    text => join("\n", @result),
    icon_emoji => ":github:",
);

