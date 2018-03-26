# requested reviewers notifier

## Description

リポジトリの Pull Request に指定されている Reviewer を Slack に通知する。

## Screenshot

![Screenshot](https://github.com/waniji/requested-reviewers-notifier/blob/master/screenshot.png)

## Usage

```
# Execute with command line args
notifier.pl --github_repos=waniji/requested-reviewers-notifier,waniji/dotfiles --github_token=xxxxxx --slack_token=xxxxxx --slack_channel=#sample-channel

# Execute with config file
notifier.pl --config=config.js
```

## Config

引数ではなく設定ファイルを使って実行する。

```json
{
    "github_repos": [
        "waniji/requested-reviewers-notifier",
        "waniji/dotfiles"
    ],
    "github_token": "xxxxxx",
    "slack_token": "xxxxxx",
    "slack_channel": "#sample-channel"
}
```

