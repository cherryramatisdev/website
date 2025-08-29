+++
title = "You Can Just Script Things With Tmux"
date = "2025-06-02T12:28:44-03:00"
author = ["Cherry Ramatis"]
tags = ["automation", "tmux"]
description = "I'll show and explain some of my scripts to automate tmux and take the most out of it, shall we?"
draft = true
+++

Every time someone tell me how they changed which terminal emulator they used and are now learning a new set of key bindings or configuring it to match the already learned ones I think with me "I'm so glad I use tmux", don't get me wrong I love modern terminal emulators (I'm daily driving ghostty right now), I just can't understand why the terminal emulator need to worry about splitting, session management, etc. Specially when that solution is always worse and less scriptable than plan tmux (or zellij, I don't use but see you)

## Let's start simple, a script to set up project

```perl
#!/usr/bin/env perl

use warnings;
use strict;
use v5.14;

my $project_to_run = `ls $PROJECT_FOLDER | fzf`;
chomp($project_to_run);

my %actions = (
    "project-1" => sub {
            system("tmux send-keys 'yarn start' C-m");
            system("tmux split-window -h");
            system("tmux send-keys 'cd $PROJECT_FOLDER/api-mock/ && yarn start' C-m");
            system("tmux select-pane -L");
            system("tmux split-window -v");
            system("tmux send-keys 'cd $PROJECT_FOLDER/container-frontend/ && yarn start' C-m");
        },
);

# Example usage:
if (exists $actions{$project_to_run}) {
    $actions{$project_to_run}->();
    exit 0;
}

say "Can't find any runner configuration for this project, sorry";
```

This one is quite interest if you never scripted with tmux as a CLI before, we have a couple nice commands:

1. `split-window` :: This one
