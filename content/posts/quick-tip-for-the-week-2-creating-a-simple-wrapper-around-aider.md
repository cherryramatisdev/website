---
title: "Quick Tip for the Week #2: Creating a simple wrapper around aider (AI assistant)"
author: Cherry Ramatis
date: 2025-09-13
tags:
  - tech
  - nvim
  - ai
  - agent
keywords:
  - neovim
  - nvim
  - ai
  - agents
draft: false
---
I'm not the biggest fan of AI usage while coding, but it's definitely changed the way we produce and thinkg about code, so I decided to give it a try and integrate into my workflow (tried copilot in the past and couldn't get used to the AI completion popping off all the time). After some months testing I settle myself with a working workflow: Just a chat assistant opened close to my editor which I can either use as an alternative to modern search engines when the query is too complex or to maintain a persistent conversation about possible solutions. I've being quite happy with that setup so far as it keeps me in control of the code that it's being shipped while also benefitting from that speed of using an LLM. For the chat integration I chose using the [aider chat](https://aider.chat/).

As with all things we include in our workflow, I just used the simplest way that is opening a pane alongside my editor and running the `aider` command, but the more I used the more that familiar question began to rise - "Can this be automated? Can this be more efficient?" - And the quick question is: It absolutely can! Let's bring this to work inside neovim!


## Demo + the whole module {#demo-plus-the-whole-module}

As always, if you just want to copy this module to your config and be done with the post, you're more than welcome to do that! below is the whole module that I keep in `plugin/aider.lua` and the link to the demo.

```lua
vim.g.aider_cmd = 'aider'

local function is_buffer_visible(bufnr)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_buf(win) == bufnr then
            return true
        end
    end
    return false
end

local function get_aider_buffer()
    local buffers = vim.api.nvim_list_bufs()
    ---@type {buf: number, name: string}|nil
    local aider_buffer = nil

    for _, buf in ipairs(buffers) do
        local name = vim.api.nvim_buf_get_name(buf)
        if string.find(name, vim.g.aider_cmd) ~= nil then
            aider_buffer = { buf = buf, name = name }
        end
    end

    return aider_buffer
end

---@param job_id number Can be retrieved through vim.api.nvim_buf_get_var(buf, 'terminal_job_id')
---@param cmd string
local function send_command_to_aider(job_id, cmd)
    local meta_enter_sequence = '\x1b\r'
    vim.api.nvim_chan_send(job_id, cmd .. meta_enter_sequence)
end

---@param cmd string
local function run_aider_command(cmd)
    local aider_buffer = get_aider_buffer()

    if not aider_buffer then
        vim.notify('You must first open an aider session by pressing <leader>aa', vim.log.levels.ERROR)
        return
    end

    local job_id = vim.api.nvim_buf_get_var(aider_buffer.buf, "terminal_job_id")

    send_command_to_aider(job_id, cmd)
end

vim.keymap.set('n', '<leader>aa', function()
    local aider_buffer = get_aider_buffer()
    local original_win = vim.api.nvim_get_current_win()

    local small_vertical_window_cmd = 'vert botright 70vsplit'

    if not aider_buffer then
        vim.cmd(small_vertical_window_cmd .. ' | term ' .. vim.g.aider_cmd)
        vim.api.nvim_set_current_win(original_win)
        return
    end

    if is_buffer_visible(aider_buffer.buf) then
        local winid = vim.fn.bufwinnr(aider_buffer.buf)

        vim.api.nvim_win_close(vim.fn.win_getid(winid), false)
        return
    end

    vim.cmd(small_vertical_window_cmd)
    vim.cmd.b(aider_buffer.name)
    vim.api.nvim_set_current_win(original_win)
end, { desc = '[AI] Toggle aider buffer' })

vim.keymap.set('n', '<leader>af', function()
    run_aider_command('/add ' .. vim.fn.expand('%:p'))
end, { desc = '[AI] Add current file to aider session' })

vim.keymap.set('n', '<leader>ad', function()
    run_aider_command('/drop ' .. vim.fn.expand('%:p'))
end, { desc = '[AI] Drop current file from aider session' })

vim.keymap.set('n', '<leader>aD', function()
    run_aider_command('/drop')
end, { desc = '[AI] Drop all files from aider session' })

vim.keymap.set('n', '<leader>aq', function()
    vim.ui.select({ 'yes', 'no' }, {
        prompt = 'Are you sure you want to quit the session?',
    }, function(choice)
        if choice == 'yes' then
            local aider_buffer = get_aider_buffer()

            if not aider_buffer then
                vim.notify('You must first open an aider session by pressing <leader>aa', vim.log.levels.ERROR)
                return
            end

            run_aider_command('/quit')
            vim.api.nvim_buf_delete(aider_buffer.buf, { force = true })
        end
    end)
end, { desc = '[AI] Drop all files from aider session' })
```

{{< figure src="https://asciinema.org/a/737600.svg" link="https://asciinema.org/a/737600" >}}


## Breaking up piece by piece {#breaking-up-piece-by-piece}

Ok, since you're interested in how this works, let's go bit by bit and hopefully learn something new about lua or the nvim API!

---

**1. Toggling the buffer**

To achieve this behavior we need two main functions `get_aider_buffer()` and `is_buffer_visible()`, these will respectively search for an already started terminal buffer with aider running and check if that buffer is already opened or not.

Both are quite simple, for the first function (which you can see below) we loop through all the buffers returned from `vim.api.nvim_list_bufs()` and check if the buffer name (`vim.api.nvim_buf_get_name(buf)`) has a substring that matches our `vim.g.aider_cmd`. We use a substring because the full name of the buffer will be something like this: `term://~/git/blog//1403:<<cmd>>` where the `<<cmd>>` will be our configured aider command.

> PS: I chose to have the \`vim.g.aider_cmd\` just to facilitate customization, I use a personal script that attaches a bunch of flags to aider (I'll include the script by the end of the post to anyone interested)

```lua
local function get_aider_buffer()
    local buffers = vim.api.nvim_list_bufs()
    ---@type {buf: number, name: string}|nil
    local aider_buffer = nil

    for _, buf in ipairs(buffers) do
        local name = vim.api.nvim_buf_get_name(buf)
        if string.find(name, vim.g.aider_cmd) ~= nil then
            aider_buffer = { buf = buf, name = name }
        end
    end

    return aider_buffer
end
```

For the second mentioned function, that check if a buffer is visible is even simpler. This function will only check if among all the windows opened on the current tab if one of them has the target `bufnr` (buffer number) attached to it.

```lua
local function is_buffer_visible(bufnr)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_buf(win) == bufnr then
            return true
        end
    end
    return false
end
```

With these two functions we have our full toggling command done, where we split into three possible actions:

1.  _The buffer doesn't exist_ :: In that case we open a vertical split with 70 of width and run the terminal command on it.
2.  _The buffer exist and it's visible in the current tab_ :: In that case we find the window attached to the buffer and close **only the window, not the buffer**
3.  _The buffer exist and itsn't visible in the current tab_ :: In that case, we open the vertical split and attach the existing buffer to it's window.

<!--listend-->

```lua
vim.keymap.set('n', '<leader>aa', function()
    local aider_buffer = get_aider_buffer()
    local original_win = vim.api.nvim_get_current_win()

    local small_vertical_window_cmd = 'vert botright 70vsplit'

    if not aider_buffer then
        vim.cmd(small_vertical_window_cmd .. ' | term ' .. vim.g.aider_cmd)
        vim.api.nvim_set_current_win(original_win)
        return
    end

    if is_buffer_visible(aider_buffer.buf) then
        local winid = vim.fn.bufwinnr(aider_buffer.buf)

        vim.api.nvim_win_close(vim.fn.win_getid(winid), false)
        return
    end

    vim.cmd(small_vertical_window_cmd)
    vim.cmd.b(aider_buffer.name)
    vim.api.nvim_set_current_win(original_win)
end, { desc = '[AI] Toggle aider buffer' })
```

> In the cmd that we use to open the split you can see `vert botright`, this is used so we open the chat buffer on the farthest right of the page, so even when we have a couple vertical splits opened, the chat will open after all of them

**2. Sending commands to that buffer**

wip...
