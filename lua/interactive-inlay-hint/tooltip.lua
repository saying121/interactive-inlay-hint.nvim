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
function M:init(markdown_lines, super_win)
    self.bufnr = api.nvim_create_buf(false, true)

    local width = utils.max_width(markdown_lines)
    local height = #markdown_lines

    local win_opts = vim.tbl_extend("keep", config.values.win_opts, {
        win = super_win,
        -- width = utils.max_width(markdown_lines),
        -- height = #markdown_lines,
        border = "rounded",
        relative = "win",
        row = 1,
        col = -1,
        title = "tooltip",
        title_pos = "center",
    })
    utils.min_width_height(win_opts, width, height)

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
        api.nvim_win_close(self.winnr, true)
        self.winnr = nil
        self.bufnr = nil
    end
end

return M
