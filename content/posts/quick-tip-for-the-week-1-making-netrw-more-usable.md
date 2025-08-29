+++
title = "Quick Tip for the Week #1: Making Netrw More Usable"
date = "2025-08-27T12:29:58-03:00"
author = ["Cherry Ramatis"]
tags = ["nvim", "tech"]
keywords = ["nvim", "netrw", "file", "explorer"]
description = "Let's understand a few minor tweaks to make netrw a pretty decent file browser."
showFullContent = false
readingTime = true
hideComments = false
+++

It's definitely not new to any Neovim user that we have **a lot** of file browser plugins, all over from the super minimalistic, like [vim-dirvish,](https://github.com/justinmk/vim-dirvish) to the full-blown new experiences like [oil.nvim](https://github.com/stevearc/oil.nvim) or [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim). But what about netrw? You know, that file browser that comes default with (Neo)Vim and certainly has some weird behaviors? Recently I started thinking about what could be done to fix some of those weird behaviors and potentially remove yet another plugin in my crusade for minimalism. As always, I hope you find something useful for your own config. :)

Most of the problems I personally faced were understanding how moving and copying work. I really like the concept of pressing `mf` to mark the files you want to operate on, but then it gets really cumbersome to set the target directory and operate the exact right settings to perform your action. We can improve this; it's absolutely possible to remove small extra steps to have a quite competent file browser to use on a day-to-day basis.

## Oil vs Vinegar (or Tree View vs Buffer View)

One of my favorite videos about Vim was [this one](https://www.youtube.com/watch?v=OgQW07saWb0) by [@greghurrel](https://github.com/wincent) published in 2019 because it explains a quite old discussion that we're still having today in the Neovim community, which is tree view VS buffer views for a file browser, which at the time was represented by the plugins NERDTree and vim-vinegar, respectively.

I personally never use tree view file browsers because, in my opinion, worrying about the folder structure is not something you should always be doing, so it's not worth it to automate it with a plugin. It does happen, but it's ok to just use `tree` at the shell, although I understand that each person has a different mental model and the tree view can be quite effective and useful for someone. For this particular post, we'll focus only on the buffer view part of netrw provided by the vim-vinegar (or oil.nvim for the modern ones).

## Ok ok, show me the code

If you find this workflow interesting, below is the whole module that you can put at `ftplugin/netrw.lua` or control with an autocmd if preferable. Also, I included two demos demonstrating basic operations and the renaming integration with the [snacks](https://github.com/folke/snacks.nvim) plugin.

```lua
-- ftplugin/netrw.lua
vim.opt_local.winbar = '%f'

local function refresh_netrw()
  vim.cmd(':Ex ' .. vim.b.netrw_curdir)
end

vim.keymap.set("n", "mc", function()
  local target_dir = vim.b.netrw_curdir
  local file_list = vim.fn["netrw#Expose"]("netrwmarkfilelist")
  if #file_list > 0 then
    for _, node in pairs(file_list) do
      vim.uv.fs_copyfile(node, target_dir .. "/" .. vim.fs.basename(node), { excl = true })
    end

    refresh_netrw()
    vim.cmd [[ call netrw#Modify("netrwmarkfilelist",[]) ]]
  end
end, { remap = true, buffer = true })

vim.keymap.set("n", "mm", function()
  local target_dir = vim.b.netrw_curdir
  local file_list = vim.fn["netrw#Expose"]("netrwmarkfilelist")
  if #file_list > 0 then
    for _, node in pairs(file_list) do
      local file_name = vim.fs.basename(node)
      local target_exists = vim.uv.fs_access(target_dir .. "/" .. file_name, "W")
      if not target_exists then
        vim.uv.fs_rename(node, target_dir .. "/" .. file_name)
      else
        print("File '" .. file_name .. "' already exists! Skipping...")
      end
    end

    refresh_netrw()
    vim.cmd [[ call netrw#Modify("netrwmarkfilelist",[]) ]]
  end
end, { remap = true, buffer = true })

vim.keymap.set("n", "R", function()
  local original_file_path = vim.b.netrw_curdir .. '/' .. vim.fn["netrw#Call"]("NetrwGetWord")

  vim.ui.input({ prompt = 'Move/rename to:', default = original_file_path, completion = 'file' }, function(target_file_path)
    if target_file_path and target_file_path ~= "" then
      local file_exists = vim.uv.fs_access(target_file_path, "W")

      if not file_exists then
        vim.uv.fs_rename(original_file_path, target_file_path)

        if Snacks then
          Snacks.rename.on_rename_file(original_file_path, target_file_path)
        end
      else
        vim.notify("File '" .. target_file_path .. "' already exists! Skipping...", vim.log.levels.ERROR)
      end

      refresh_netrw()
    end
  end)
end, { remap = true, buffer = true })

vim.keymap.set('n', 'gcd', function()
  vim.ui.input({ prompt = 'Path: ', completion = 'dir' }, function(input)
    if input and input ~= "" then
      vim.cmd('Ex ' .. input)
    end
  end)
end, { buffer = true, silent = true })
```

**Demo #1: File manipulation and path completion**

[![demo #1: File manipulation and path completion](https://asciinema.org/a/736493.svg)](https://asciinema.org/a/736493)

**Demo #2: LSP Rename on file rename with [snacks.nvim](https://github.com/folke/snacks.nvim)**

[![demo #2: LSP Rename on file rename with Snacks](https://asciinema.org/a/735692.svg)](https://asciinema.org/a/735692)

## Final thoughts

If you would change anything, please reach me out so we can talk about it :) May the force be with you 🍒.
