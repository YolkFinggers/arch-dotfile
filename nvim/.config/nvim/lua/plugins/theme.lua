return {
  -- {
  --   'scottmckendry/cyberdream.nvim',
  --   lazy = false,
  --   priority = 1000,
  --
  --   config = function()
  --     require('cyberdream').setup {
  --       -- ... other config
  --       transparent = true,
  --
  --       -- Reduce the overall saturation of colours for a more muted look
  --       saturation = 1, -- accepts a value between 0 and 1. 0 will be fully desaturated (greyscale) and 1 will be the full color (default)
  --
  --       -- Enable italics comments
  --       italic_comments = true,
  --
  --       -- Apply a modern borderless look to pickers like Telescope, Snacks Picker & Fzf-Lua
  --       borderless_pickers = false,
  --
  --       -- Set terminal colors used in `:terminal`
  --       terminal_colors = true,
  --
  --       cache = true, -- Use cache for fastest loads
  --       extensions = {
  --         -- Alternatively, you can use 'default' to set all extensions at once
  --         default = true, -- Disable all by default
  --         base = true, -- Enable all built-in hl groups (you probably want this)
  --
  --         -- Now enable only what you want to use
  --         -- telescope = true,
  --         -- cmp = true,
  --         -- gitsigns = true,
  --       },
  --     }
  --
  --     vim.cmd 'colorscheme cyberdream'
  --   end,
  -- },
  {
    -- You can easily change to a different colorscheme.
    -- Change the name of the colorscheme plugin below, and then
    -- change the command in the config to whatever the name of that colorscheme is.
    --
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
    'folke/tokyonight.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        styles = {
          comments = { italic = false }, -- Disable italics in comments
          floats = 'transparent',
        },
        transparent = true,
      }

      -- Load the colorscheme here.
      -- Like many other themes, this one has different styles, and you could load
      -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
      vim.cmd [[colorscheme tokyonight-storm]]
    end,
  },
}
