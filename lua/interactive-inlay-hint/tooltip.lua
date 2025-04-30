local api = vim.api
local keymap = vim.keymap.set
local utils = require("interactive-inlay-hint.utils")
local config = require("interactive-inlay-hint.config")

local M = {
    ---@type integer
    winnr = nil,
    ---@type integer
    bufnr = nil,
}

---@param markdown_lines string[]
---@param super_win integer
function M:init(markdown_lines, super_win, col)
    self.bufnr = api.nvim_create_buf(false, true)

    local width = utils.max_width(markdown_lines)
    local height = #markdown_lines

    ---@diagnostic disable-next-line: undefined-field
    local leftcol = vim.fn.getwininfo(super_win)[1].leftcol

    local win_opts = vim.tbl_extend("keep", config.values.win_opts, {
        win = super_win,
        border = "rounded",
        relative = "win",
        row = 2,
        col = col - 1 - leftcol,
        title = "tooltip",
        title_pos = "center",
    })
    win_opts.height = math.min(win_opts.height, height)
    win_opts.width = width

    self.winnr = api.nvim_open_win(self.bufnr, false, win_opts)

    api.nvim_buf_set_lines(self.bufnr, 0, #markdown_lines, false, markdown_lines)

    utils.set_win_buf_opt(self.winnr, self.bufnr)

    keymap("n", "q", function()
        self:close_hover()
    end, { buffer = self.bufnr, silent = true })
    keymap("n", "<Esc>", function()
        self:close_hover()
    end, { buffer = self.bufnr, silent = true })
end

function M:close_hover()
    if self.winnr ~= nil then
        pcall(api.nvim_win_close, self.winnr, true)
        self.winnr = nil
        self.bufnr = nil
    end
end

return M
