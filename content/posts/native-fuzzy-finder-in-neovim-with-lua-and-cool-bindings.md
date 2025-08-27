+++
title = "Native Fuzzy Finder in Neovim With Lua and Cool Bindings"
date = "2025-08-25T11:25:34-03:00"
author = ["Cherry Ramatis"]
tags = ["nvim", "tech"]
keywords = ["nvim", "fuzzy", "finder"]
description = "I built a native fuzzy finder in Neovim to remove yet another plugin and enjoy the latest goods shipped to the main branch."
showFullContent = false
readingTime = true
hideComments = false
+++

Recently, I read a particular [blog post by yobibyte](https://yobibyte.github.io/vim.html) about a no-plugins approach to Neovim configuration, which stuck with me. I started to think more and more about how much stuff I really need for my config to suit my needs. Personally, the main reason why I resonate so much with a particular family of editors (Vim, Nvim, Kakoune, Emacs, etc.) is the ability to add as much stuff as you want, but at the same time the opportunity to remove as much bloat as possible—a little controversial, but if you think about it, it's the best scenario for customizability. I remember watching a video about the concept of a [PDE](https://www.youtube.com/watch?v=QMVIJhC9Veg) coined by a Neovim contributor called teej_dv, and it really stuck with me. These types of editors are more like an environment than just a product with a single goal.

Well, this is the exact situation I'm currently in, trying to experiment with native functions from Neovim and writing tiny wrappers around them instead of using plugins that recreate the whole UX. I hope you find this particular "wrapper" useful for your workflow. :)

> First things first, it's important to point out that I'm using neovim nightly, this is important because we need two particular patches to make all this work properly, which is this the [vim patch adding wildtrigger() function for cmdline completion](https://github.com/vim/vim/pull/17806) ([neovim equivalent](https://github.com/neovim/neovim/pull/35022)) and the [vim patch adding findfunc as a option](https://github.com/vim/vim/pull/15976) ([neovim equivalent](https://github.com/neovim/neovim/pull/31058)). If at the time you're reading this post those patches are already available at stable version, you don't need to worry with building from source.

For the ones with a practical sense, this is the whole module I have at `plugin/cmdline.lua` for you to copy and try for yourself. Throughout this blog post, we'll break up piece by piece how it works.

You can also find a vim9 version that originated all my thoughts around this theme: <https://www.reddit.com/r/vim/comments/1mvzitt/yet_another_simple_fuzzy_file_finder/>

```lua
if vim.fn.executable "rg" == 1 then
    function _G.RgFindFiles(cmdarg, _cmdcomplete)
        local fnames = vim.fn.systemlist('rg --files --hidden --color=never --glob="!.git"')
        if #cmdarg == 0 then
            return fnames
        else
            return vim.fn.matchfuzzy(fnames, cmdarg)
        end
    end

    vim.o.findfunc = 'v:lua.RgFindFiles'
end

local function is_cmdline_type_find()
    local cmdline_cmd = vim.fn.split(vim.fn.getcmdline(), ' ')[1]

    return cmdline_cmd == 'find' or cmdline_cmd == 'fin'
end

vim.api.nvim_create_autocmd({ 'CmdlineChanged', 'CmdlineLeave' }, {
    pattern = { '*' },
    group = vim.api.nvim_create_augroup('CmdlineAutocompletion', { clear = true }),
    callback = function(ev)
        local function should_enable_autocomplete()
            local cmdline_cmd = vim.fn.split(vim.fn.getcmdline(), ' ')[1]

            return is_cmdline_type_find() or cmdline_cmd == 'help' or cmdline_cmd == 'h'
        end

        if ev.event == 'CmdlineChanged' and should_enable_autocomplete() then
            vim.opt.wildmode = 'noselect:lastused,full'
            vim.fn.wildtrigger()
        end

        if ev.event == 'CmdlineLeave' then
            vim.opt.wildmode = 'full'
        end
    end
})

vim.keymap.set('n', '<leader>f', ':find<space>', { desc = 'Fuzzy find' })

vim.keymap.set('c', '<m-e>', '<home><s-right><c-w>edit<end>', { desc = 'Change command to :edit' })
vim.keymap.set('c', '<m-d>', function()
    if not is_cmdline_type_find() then
        vim.notify('This binding should be used with :find', vim.log.levels.ERROR)
        return
    end

    local cmdline_arg = vim.fn.split(vim.fn.getcmdline(), ' ')[2]

    if vim.uv.fs_realpath(vim.fn.expand(cmdline_arg)) == nil then
        vim.notify('The second argument should be a valid path', vim.log.levels.ERROR)
        return
    end

    local keys = vim.api.nvim_replace_termcodes(
        '<C-U>edit ' .. vim.fs.dirname(cmdline_arg),
        true,
        true,
        true
    )
    vim.fn.feedkeys(keys, 'c')
end, { desc = 'Edit the dir for the path' })

vim.keymap.set('c', '<c-v>', '<home><s-right><c-w>vs<end>', { desc = 'Change command to :vs' })
vim.keymap.set('c', '<c-s>', '<home><s-right><c-w>sp<end>', { desc = 'Change command to :sp' })
vim.keymap.set('c', '<c-t>', '<home><s-right><c-w>tabe<end>', { desc = 'Change command to :tabe' })
```

And here is a demo showing off all the features available:

> Disclaimer: The screenkey plugin here is a bit laggy so consider referencing the keybinds with the code block above if something was confusing.

[![demo](https://asciinema.org/a/735657.svg)](https://asciinema.org/a/735657)

## Breaking up piece by piece

OK! Time to dive into this module. The first feature that honestly made all this even possible is the simplest to explain: the `findfunc` option. This patch was merged into Neovim in November 2024 from a Vim patch and introduced the possibility of customizing how the editor searched files using the `:find` cmd.

Historically, Vim users that wanted a more native file finder were using a rather hacky trick that consisted of configuring the `path` option with a glob pattern like this: `set path+=**`. By adding this, the `:find` command could expand to the whole project structure to find a file. The problem? Performance: It's quite slow using the GNU find binaries in large codebases.

But with `findfunc`, we can make this command use faster binaries like `fd`, `rg` or even using our favorite VCS like `git ls-files` to increase the initial performance hit of loading the files. Basically, we have a functional file finder now! Yay!

All this is nice, but it's missing one important piece to the function: fuzzy matching. You know, that thing that makes the telescope plugin really shine, that allows you to type roughly the file name and still get the correct matches? We can achieve this by using the `matchfuzzy` to further filter the options as the user types.

This sums up our first function:

```lua
function _G.RgFindFiles(cmdarg, _cmdcomplete)
    local fnames = vim.fn.systemlist('rg --files --hidden --color=never --glob="!.git"')
    if #cmdarg == 0 then
        return fnames
    else
        return vim.fn.matchfuzzy(fnames, cmdarg)
    end
end

vim.o.findfunc = 'v:lua.RgFindFiles'
```

As you can see, the `cmdarg` is the substring typed by the user (it's nil when the user didn't type anything). For this function, we separate into returning the whole list of files when the user hasn't typed anything yet and returning the fuzzy matched list according to the substring provided. The function will be called every time the user manually presses the `<tab>` key, and all the details regarding the limit of items shown and navigation are dealt with by the `wildmenu` option (you can find more about it with `:h wildmenu`)

---

Nice! We now have tab-completed fuzzy finding; let's spice things up with ✨ autocompletion ✨. I'm not a particular fan of autocompletion when I'm typing on a buffer, but it certainly fits perfectly when filtering file paths.

For this to be possible comes our second patch that introduced the `wildtrigger()` function. It is quite simple in theory: it triggers completion programmatically when on the cmdline, it works for commands like `/` `:s` and, of course, `:find`. When combined with the autocmd event `CmdlineChanged` we can programmatically trigger the completion every time we type a character into the cmdline, cool, right?

The simplest version of this behavior can be declared as follows:

```lua
vim.api.nvim_create_autocmd({ 'CmdlineChanged' }, {
    pattern = { '*' },
    group = vim.api.nvim_create_augroup('CmdlineAutocompletion', { clear = true }),
    callback = function(ev)
        vim.opt.wildmenu = true
        vim.opt.wildmode = 'noselect:lastused,full'
        vim.fn.wildtrigger()
    end
})
```


> You can move the `wildmenu` and `wildmode` configuration outside the autocmd without any problems, we're just containing more in favor of control and simplicity.

Together with the `wildtrigger` function being called on every change, we have a neat setting being placed here: the `wildmode`. This option is important because it allows us to not immediately insert the first option when the completion popup appears; it's similar to what we set in `completeopt` to configure buffer autocompletion frameworks like [nvim-cmp](https://github.com/hrsh7th/nvim-cmp).

For context, let's take a look into the full description for this option from the help pages:

```help
"full"	            Complete the next full match.  Cycles through all
                    matches, returning to the original input after the
                    last match.  If 'wildmenu' is enabled, it will be
                    shown.

"noselect:lastused"	Do not preselect the first item in 'wildmenu'
				    if it is active.  When completing buffers,
				    sort them by most recently used (excluding the
				    current buffer).
```

This is already our full feature of fuzzy finding with autocomplete! Further on in this article, we'll write keymaps around the cmdline mode to improve the UX, shall we? :)

First let's constrain this autocomplete to work on specific commands. This is particularly useful to me because I don't want autocompletion in commands like `:edit`, just on the ones important to fuzzy finding (in this case, `:help` and `:find`).

```lua
vim.api.nvim_create_autocmd({ 'CmdlineChanged', 'CmdlineLeave' }, {
    pattern = { '*' },
    group = vim.api.nvim_create_augroup('CmdlineAutocompletion', { clear = true }),
    callback = function(ev)
        local function should_enable_autocomplete()
            local cmdline_cmd = vim.fn.split(vim.fn.getcmdline(), ' ')[1]

            -- NOTE: Here your can add any other variant that you commonly type to abbreviate the command. :)
            return cmdline_cmd == 'find' or cmdline_cmd == 'fin' or cmdline_cmd == 'help' or cmdline_cmd == 'h'
        end

        if ev.event == 'CmdlineChanged' and should_enable_autocomplete() then
            vim.opt.wildmode = 'noselect:lastused,full'
            vim.fn.wildtrigger()
        end

        if ev.event == 'CmdlineLeave' then
            vim.opt.wildmode = 'full'
        end
    end
})
```


There are two main aspects of this version, the *cleanup* and the *cmdline check*:

- *cleanup* :: On this version, we're listening to an additional event `CmdlineLeave` which we use to reset the `wildmode` option to the default value. This is important to not affect further commands on the cmdline. To do that, we take advantage of the `ev` parameter passed to the callback; with it we can check the `.event` and perform different actions.
- *cmdline check* :: With the function `vim.fn.getcmdline()` we get the whole content of the cmdline typed so far as a string, considering that it is just a matter of string parsing to get the parts we want. To keep it simple, we're just splitting on spaces and checking the first word (the command).

Great! Our current version has a controlled autocompletion based on the command and a fuzzy finding method attached to it. What else is needed? Now we'll add the convenient strategies implied by plugin fuzzy finders to open the selection on splits and other cool additions that worked for me personally.

I need to be honest here; some of these keymaps I got the idea from Emacs (no judgments), and it suited so well with this finder. Some of them are quite simple, and we'll start off with them!

```lua
vim.keymap.set('c', '<m-e>', '<home><s-right><c-w>edit<end>', { desc = 'Change command to :edit' })
vim.keymap.set('c', '<c-v>', '<home><s-right><c-w>vs<end>', { desc = 'Change command to :vs' })
vim.keymap.set('c', '<c-s>', '<home><s-right><c-w>sp<end>', { desc = 'Change command to :sp' })
vim.keymap.set('c', '<c-t>', '<home><s-right><c-w>tabe<end>', { desc = 'Change command to :tabe })
```

Quite simple, right? All of them do the same thing: they change the command to achieve different actions like opening on a split, a tab, etc. Let's break the syntax briefly:

- `<home><s-right><c-w>` :: This sequence first sends the cursor to the beginning of the line (`<home>`), then navigates one word to the right (`<s-right>` or `shift+right`) and finally deletes the word from right to left (`<c-w>` or `ctrl+w`). Leaving the cmdline without the command, for example, `:<<cursor_here>> plugin/cmdline.lua`
- word + `<end>` :: Here it is quite straightforward; the `word` changes from each command, and the `<end>` sends the cursor to the end of the line, so you can continue typing or press enter to confirm the command.

Got it? These bindings already bring up the functionalities provided by common fuzzy finders, but let's go a little further with an additional keymap: manipulate the current path to get the directory instead. The purpose is to easily open the directory for a file to move/copy/delete something.

```lua
vim.keymap.set('c', '<m-d>', function()
    local cmdline = vim.fn.split(vim.fn.getcmdline(), ' ')

    local cmdline_cmd = cmdline[1]

    if not (cmdline_cmd == 'find' or cmdline_cmd == 'fin') then
        vim.notify('This binding should be used with :find', vim.log.levels.ERROR)
        return
    end

    local cmdline_arg = cmdline[2]

    if vim.uv.fs_realpath(vim.fn.expand(cmdline_arg)) == nil then
        vim.notify('The second argument should be a valid path', vim.log.levels.ERROR)
        return
    end

    local keys = vim.api.nvim_replace_termcodes(
        '<C-U>edit ' .. vim.fs.dirname(cmdline_arg),
        true,
        true,
        true
    )
    vim.fn.feedkeys(keys, 'c')
end, { desc = 'Edit the dir for the path' })
```

The initial part parses the whole cmdline string (like we saw earlier about the usage of `vim.fn.getcmdline()`) to check if the current command is `:find` and if the second argument is a valid path. We just want to process these cases.

The cmdline manipulation on this part is a little trickier because instead of just outputting the special syntax like the previous keymaps, we need to do it programmatically. For this to be possible, we need two important functions: `vim.api.nvim_replace_termcodes` and `vim.fn.feedkeys`.

- `vim.api.nvim_replace_termcodes` :: This function transforms special syntax like `<c-u>` into a version commonly used in shells; it mostly transforms these modifiers into [escape sequences](https://en.wikipedia.org/wiki/Escape_sequence) like `^\U` for `ctrl+u`.
- `vim.fn.feedkeys` :: This function passes the sequence of keys and tries to mimic them into the mode specified. For our case it's mimicking the key sequence with the cmdline mode `'c'`. It emulates what would happen if you had typed that sequence manually.

> Another important function is the `vim.fs.dirname` one, this function receive a path as argument and return the path to the parent directory of it, like the following:
>
> ```lua
> vim.fs.dirname("plugin/cmdline.lua") -- "plugin"`
> vim.fs.dirname("/home/user/.config/nvim/after/plugin/test.lua") -- "/home/user/.config/nvim/after/plugin/"`
> ```

Having explained these functions, we can sum up the behavior of the binding like the following: For the `:find` command, by pressing `option+d` or `alt+d` we replace the path with the parent directory version of it, allowing you to open your file browser of choice. 

> The `<c-u>` or `ctrl+u` triggered from the function delete the content of the whole line.

## Final thoughts

I hope some of this is useful for you reading it! Either by knowing a new function or some interesting behavior that you didn't know about nvim, the main goal with these explorations is to know more about the editor we all use every day. Feel free to reach out so we can talk more about this topic. :) May the Force be with you. 🍒.
