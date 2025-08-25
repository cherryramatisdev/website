+++
title = "Native Fuzzy Finder in Neovim With Lua and Cool Bindings"
date = "2025-08-25T11:25:34-03:00"
dateFormat = "02/01/2006"
author = ["Cherry Ramatis"]
tags = ["nvim", "tech"]
keywords = ["nvim", "fuzzy", "finder"]
description = "Built a native fuzzy finder in neovim to remove yet another plugin and enjoy the latest goods shipped to the main branch."
showFullContent = false
readingTime = true
hideComments = false
+++

Since I read a particular [blog post by yobibyte](https://yobibyte.github.io/vim.html) about a minimalist approach to neovim configuration I started to think more about how much stuff do I really need for my config to work properly, particularly the main reason why I resonate so much with a particular family of editors (vim, nvim, kakoune, emacs, etc) is the ability to remove as much bloat as you want, keeping only the powerful features that make sense **to you**. It's totally fine to use a neovim distro on the beginning of your journey, but give a chance to start piece by piece, you'll be amazed by how few things you actually need to write and code at your best (If you're interested in this discussion I highly recommend taking a look at the [PDE concept coined by teej_dv](https://www.youtube.com/watch?v=QMVIJhC9Veg).

> First things first, it's important to point out that I'm using neovim nightly built from source, this is important because we need two particular patches to make all this work properly, which is this the [vim patch adding wildtrigger() function for cmdline completion](https://github.com/vim/vim/pull/17806) ([neovim equivalent](https://github.com/neovim/neovim/pull/35022)) and the [vim patch adding findfunc as a option](https://github.com/vim/vim/pull/15976) ([neovim equivalent](https://github.com/zeertzjq/neovim/commit/24d448aeb6cbbe12bb85c7eec3ee0201336b19fa)).

This is the whole module I have at `plugin/cmdline.lua` for you to copy, we'll break up piece by piece:

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
vim.keymap.set('c', '<c-s>', '<home><s-right><c-w>sp<end>', { desc = 'Change command to :vs' })
```

And here is a demo showing up all the features:

[![demo](https://asciinema.org/a/735657.svg)](https://asciinema.org/a/735657)

## Breaking up piece by piece

OK, now let's dive in piece by piece. The first thing the should drag your eyes is the `findfunc` piece, this part is responsible for making the `:find` command useful in large codebases, with this option we can provide a function that return a list of strings and match as the user type a substring. For our implementation we use exclusively `rg --files` to get our file list fast and them proceed to fuzzy match using the native vim function `matchfuzzy`.

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

As you can see, the `cmdarg` is the substring typed by the user so we check if it exists or not, if it does we fuzzy match and if not we just return the full list of files (that happens when the user first type `:find <tab>`).

> I personally didn't understand the `cmdcomplete` purpose. It's a boolean parameter and I didn't get the utility from the help pages, if you understood feel free to reach out ^^. For this particular use case it's ok to just ignore it though.

---

Now for the cmdline autocompletion bit we'll be using the new `wildtrigger()` function and enable only for some commands, if you want to enable the autocompletion for any cmdline interaction just use the simpler version of it:

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

This `wildmode` option used here is important to not select the first option even if it's active (with this option, the option will be selected only by pressing `<tab>`). You can find the whole explanation into `:h wildmode'

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

For our full implementation we're just adding a layer to enable this behavior when we're on particular commands and disable when we leave the cmdline mode.

```lua
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
```

The main parts are the *event checking* and the *cmdline manipulation*:

- *event checking* :: On this version, we're listening for one additional event `CmdlineLeave` which we use to clean up the `wildmode` option to the default behavior. To do this we take advantage of the `ev` passed to the callback, with it we can check the type of the event and perform different actions.
- *cmdline manipulation* :: The function `vim.fn.getcmdline()` return the whole content of the cmdline typed so far, with this we can do a whole lot of string parsing, in this case we're simply splitting into spaces and checking the first word (which is the command).

It's done this way because I don't like autocompletion everywhere, so when I'm using any regular command (e.g `:Ex`) I want to keep that default behavior of pressing tab to immediately insert the completion option.

---

Finally reaching for the mappings! Particularly this is the most interesting part if you ask me, it got so much cool features (most of them I got from emacs don't judge)

First let's talk about the command manipulation ones:

```lua
vim.keymap.set('c', '<m-e>', '<home><s-right><c-w>edit<end>', { desc = 'Change command to :edit' })
vim.keymap.set('c', '<c-v>', '<home><s-right><c-w>vs<end>', { desc = 'Change command to :vs' })
vim.keymap.set('c', '<c-s>', '<home><s-right><c-w>sp<end>', { desc = 'Change command to :vs' })
```

All of them use the same "template", let's look into it more in detail:

- `<home><s-right><c-w>` :: This sequence first send the cursor to the beginning of the line (`<home>`), then navigate one word to the right (`<s-right>` or `shift+right`) and finally delete the word from right to left (`<c-w>` or `ctrl+w`). Leaving the cmdline without the command, for example `:<<cursor_here>> plugin/cmdline.lua`
- word + `<end>` :: Here is quite straightforward, the `word` changes from each command and the `<end>` send the cursor to the end of the line, so you can continue typing or press enter to confirm the command.

Now for the more involved one, let's take a look into the `"Edit the dir for the path"` key bind:

```lua
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
```

The initial part parse the whole cmdline string (like we saw earlier about the usage of `vim.fn.getcmdline()`) to check if the current command is `:find` and if the second argument is a valid path. We just want to process on these cases.

The editing on this part is a little more tricky because we need to trigger it programmatically instead of just mapping one sequence of characters to another like we did on the last ones. We two main functions `vim.api.nvim_replace_termcodes` and `vim.fn.feedkeys` to trigger those characters:

- `vim.api.nvim_replace_termcodes` :: This function transform special syntax like `<c-u>` into something neovim can understand while it's feeding keys, it mostly transform these modifiers into [escape sequences](https://en.wikipedia.org/wiki/Escape_sequence) like `^\U`
- `vim.fn.feedkeys` :: This function pass the sequence of keys and tries to mimic them into the mode specify. For our case it's mimicking the key sequence with the cmdline mode `'c'`

> To avoid missing blank spots: The `vim.fs.dirname` function take a path as an argument and return a path for the parent directory of it, like the following:
>
> ```lua
> vim.fs.dirname("plugin/cmdline.lua") -- "plugin"`
> vim.fs.dirname("/home/user/.config/nvim/after/plugin/test.lua") -- "/home/user/.config/nvim/after/plugin/"`
> ```

With these functions the behavior is quite similar to the simpler key maps, we first extract the path from the cmdline and them trigger the key sequence `<c-u>` or `ctrl+u` which delete the whole line, then we type from the ground up `edit` followed by the directory path.

## Conclusion

Hope this is useful for anyone reading it, I'm still exploring more ways to better use native features and will explain it here once I find anything useful like this one. Feel free to reach out and talk about the solution or the quality of the post itself, any tips to improve the solution or my writing is much welcome.
