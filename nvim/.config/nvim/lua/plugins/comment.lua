return {
  'numToStr/Comment.nvim',
  opts = {
    -- add any options here
  },
  config = function()
    require('Comment').setup()

    -- Add this right after setup to support blade files
    local ft = require 'Comment.ft'
    ft.blade = '{{-- %s --}}'
  end,
}
