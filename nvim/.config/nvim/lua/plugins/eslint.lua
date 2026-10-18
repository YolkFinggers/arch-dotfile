-- Auto break line after function finally?
return {
  'esmuellert/nvim-eslint',
  config = function()
    require('nvim-eslint').setup {}
  end,
}
