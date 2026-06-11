if vim.g.loaded_postonmixi2 then
  return
end
vim.g.loaded_postonmixi2 = 1

require("postonmixi2").setup()
