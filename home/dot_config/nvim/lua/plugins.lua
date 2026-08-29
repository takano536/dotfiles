local gh = function(repo)
    return 'https://github.com/' .. repo
end

vim.pack.add({
    -- Dependencies
    gh('nvim-tree/nvim-web-devicons'),
    gh('MunifTanjim/nui.nvim'),
    gh('rcarriga/nvim-notify'),

    -- UI
    gh('goolord/alpha-nvim'),
    { src = gh('catppuccin/nvim'), name = 'catppuccin' },
    gh('nvim-lualine/lualine.nvim'),
    gh('folke/noice.nvim'),
    gh('folke/trouble.nvim'),

    -- Syntax
    gh('nvim-treesitter/nvim-treesitter'),
    gh('HiPhish/rainbow-delimiters.nvim'),
}, {
    confirm = false,
})