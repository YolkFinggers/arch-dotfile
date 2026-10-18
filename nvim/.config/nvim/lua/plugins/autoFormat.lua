return { -- Autoformat
  'stevearc/conform.nvim',
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  keys = {
    {
      '<leader>f',
      function()
        require('conform').format { async = true, lsp_format = 'fallback' }
      end,
      mode = '',
      desc = '[F]ormat buffer',
    },
  },
  opts = {
    notify_on_error = true,
    -- format_on_save = function(bufnr)
    --   -- Disable "format_on_save lsp_fallback" for certain filetypes
    --   local disable_filetypes = { c = true, cpp = true }
    --   if disable_filetypes[vim.bo[bufnr].filetype] then
    --     return nil
    --   else
    --     return {
    --       timeout_ms = 2000,
    --       lsp_format = 'fallback',
    --     }
    --   end
    -- end,
    formatters_by_ft = {
      javascript = { 'prettier' },
      typescript = { 'prettier' },
      javascriptreact = { 'prettier' },
      typescriptreact = { 'prettier' },
      svelte = { 'prettier' },
      css = { 'prettier' },
      html = { 'prettier' },
      json = { 'prettier' },
      yaml = { 'prettier' },
      markdown = { 'prettier' },
      graphql = { 'prettier' },
      liquid = { 'prettier' },
      lua = { 'stylua' },
      python = { 'isort' },
      -- add more if you want: "css", "html", "markdown"
      -- Use Pint for PHP; fallback to php_cs_fixer if Pint isn't available
      php = { 'pint' },
      -- Dedicated Blade formatter
      blade = { 'blade-formatter' },
    },
    formatters = {
      ['blade-formatter'] = { -- Customize the command to include arguments
        inherit = true,
        prepend_args = {
          '--wrap-attributes',
          'force-expand-multiline',
        },
      },
      prettier = {
        inherit = true,
        prepend_args = { '--single-attribute-per-line' },
      },
    },
  },
}
