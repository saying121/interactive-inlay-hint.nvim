local api = vim.api
local keymap = vim.keymap.set
local utils = require("interactive-inlay-hint.utils")

local M = {
    ---@type integer
    winnr = nil,
    ---@type integer
    bufnr = nil,
}

---@param markdown_lines string[]
function M:init(markdown_lines)
    self.bufnr = api.nvim_create_buf(false, true)
    self.winnr = api.nvim_open_win(self.bufnr, false, {
        width = utils.max_width(markdown_lines),
        height = #markdown_lines,
        border = "rounded",
        relative = "cursor",
        row = 1,
        col = -1,
    })

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
    end
end

return M
