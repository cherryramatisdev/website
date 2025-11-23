---
title: "Quick Tip for the Week #2: Improving native fuzzy finder in neovim"
author: Cherry Ramatis
date: 2025-09-14
tags:
  - tech
  - nvim
  - fuzzy
  - finder
keywords:
  - neovim
  - nvim
  - fuzzy
  - finder
draft: false
---
> This post is a continuation to the original implementation, you can read at: <https://cherryramatis.xyz/posts/native-fuzzy-finder-in-neovim-with-lua-and-cool-bindings/>

After using the native fuzzy finder implementation everyday for almost a month now I can safely say it's quite great for my personal workflow, it works flawlessly and it's simple enough so I can extend easily. One thing though that is a bit annoying is how often the popup window updates (it updates each time you press a character), sometimes that much update add some flickering to the popup re-rendering. Luckily [Alessandro](mailto:martini97@protonmail.ch) contacted me with a better implementation that not only simplified a bit the code, but also added a debounce function to avoid that much update cycles.

To understand a comparison, below is a old vs new implementation:

_Original implementation_

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
            local cmdline_type = vim.fn.getcmdtype()

            return cmdline_type == '/' or cmdline_type == '?' or
            (cmdline_type == ':' and (is_cmdline_type_find() or cmdline_cmd == 'help' or cmdline_cmd == 'h' or cmdline_cmd == 'buffer' or cmdline_cmd == 'b'))
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

_New implementation_

> You can find the original version by @alessandro here: <https://gist.github.com/martini97/88dc592982061d55a15b826ab284a855>
>
> This version has some cool stuff like the `with_opts` function and a simplified version of the cmdline validation. In this post I focused on the debounce part because it's the one that was added to my personal configuration.

```lua
---Debounce func on trailing edge.
---@generic F: function
---@param func F
---@param delay_ms number
---@return F
local function debounce(func, delay_ms)
    ---@type uv.uv_timer_t?
    local timer = nil
    ---@type boolean?
    local running = nil
    return function(...)
        if not running then
            timer = assert(vim.uv.new_timer())
        end
        local argv = { ... }
        assert(timer):start(delay_ms, 0, function()
            assert(timer):stop()
            running = nil
            func(unpack(argv, 1, table.maxn(argv)))
        end)
    end
end

vim.api.nvim_create_autocmd({ 'CmdlineChanged', 'CmdlineLeave' }, {
    pattern = { '*' },
    group = vim.api.nvim_create_augroup('CmdlineAutocompletion', { clear = true }),
    callback = debounce(
        vim.schedule_wrap(function(ev)
            local function should_enable_autocomplete()
                local cmdline_cmd = vim.fn.split(vim.fn.getcmdline(), ' ')[1]
                local cmdline_type = vim.fn.getcmdtype()

                return cmdline_type == '/' or cmdline_type == '?' or
                (cmdline_type == ':' and (is_cmdline_type_find() or cmdline_cmd == 'help' or cmdline_cmd == 'h' or cmdline_cmd == 'buffer' or cmdline_cmd == 'b'))
            end

            if ev.event == 'CmdlineChanged' and should_enable_autocomplete() then
                vim.opt.wildmode = 'noselect:lastused,full'
                vim.fn.wildtrigger()
            end

            if ev.event == 'CmdlineLeave' then
                vim.opt.wildmode = 'full'
            end
        end),
    500)
})
```

{{< figure src="https://asciinema.org/a/740486.svg" link="https://asciinema.org/a/740486" >}}

As always, thanks for reading! May the force be with you 🍒
