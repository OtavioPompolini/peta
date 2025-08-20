-- plugin/peta.lua
-- This file is loaded automatically by Neovim

if vim.g.loaded_peta == 1 then
  return
end
vim.g.loaded_peta = 1

-- Create commands that are available before setup
vim.api.nvim_create_user_command('Peta', function()
  require('peta').toggle()
end, { desc = 'Toggle Peta HTTP Client' })

vim.api.nvim_create_user_command('PetaOpen', function()
  require('peta').show_request_list()
end, { desc = 'Open Peta HTTP Client' })

vim.api.nvim_create_user_command('PetaClose', function()
  require('peta').close()
end, { desc = 'Close Peta HTTP Client' })
