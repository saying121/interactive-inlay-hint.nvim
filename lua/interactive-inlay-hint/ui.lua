local api = vim.api
local lsp = vim.lsp
local methods = lsp.protocol.Methods
local lsp_util = lsp.util
local keymap = vim.keymap.set
local utils = require("interactive-inlay-hint.utils")

local M = {}

local function set_win_buf_opt(winnr, bufnr)
    vim.wo[winnr].signcolumn = "no"
    vim.wo[winnr].number = false
    vim.wo[winnr].rnu = false
    vim.bo[bufnr].ft = "markdown"
end

local tooltip = {
    ---@type integer
    winnr = nil,
    ---@type integer
    bufnr = nil,
}

---@param markdown_lines string[]
function tooltip:init(markdown_lines)
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

    set_win_buf_opt(self.winnr, self.bufnr)

    keymap("n", "q", function()
        self:close_hover()
    end, { buffer = self.bufnr, silent = true })
    keymap("n", "<Esc>", function()
        self:close_hover()
    end, { buffer = self.bufnr, silent = true })
end

function tooltip:close_hover()
    if self.winnr ~= nil then
        api.nvim_win_close(self.winnr, true)
        self.winnr = nil
    end
end

---@type lsp.Handler
---@param inlay_hint lsp.InlayHint
local function lsp_handler(_, inlay_hint, ctx)
    local client = lsp.get_clients({
        bufnr = ctx.bufnr,
        client_id = ctx.client_id,
        method = methods.textDocument_inlayHint,
    })[1]
    if not inlay_hint then
        return
    end

    -- ---@type lsp.InlayHintLabelPart[]
    -- local location_parts = vim.tbl_filter(
    --     ---@param part lsp.InlayHintLabelPart
    --     function(part)
    --         return part.location ~= nil
    --     end,
    --     label
    -- )
    --
    -- local part = location_parts[1]
    -- if part then
    --     client:request(methods.textDocument_hover, {
    --         textDocument = { uri = part.location.uri },
    --         position = part.location.range.start,
    --     }, function(_, result, _)
    --         handle_float(result.contents)
    --     end)
    --     return
    -- end
    --
    -- ---@type lsp.InlayHintLabelPart[]
    -- local tooltip_parts = vim.tbl_filter(
    --     ---@param part_ lsp.InlayHintLabelPart
    --     function(part_)
    --         return part_.tooltip ~= nil
    --     end,
    --     label
    -- )
    -- part = tooltip_parts[1]
    -- handle_float(part.tooltip)
end

local inlay_list_state = {
    ---@type integer
    winnr = nil,
    ---@type integer
    bufnr = nil,

    ---@type string[][]
    label_text_datas = {},
    labels_width = 0,
    ---@type (string|lsp.InlayHintLabelPart[])[]
    label_raw_datas = {},

    cur_inlay_idx = 0,
    ---@type integer
    ns_id = nil,
    ---@type integer
    extmark_id = nil,
    ref_hi = "LspReferenceText",
}

function inlay_list_state:handle_float()
    local part = self:cur_part()

    ---@type string|lsp.MarkupContent
    local input
    if type(part) == "string" then
        input = part
    else
        input = part[1].tooltip
    end

    if input == nil then
        return
    end
    local markdown_lines = lsp_util.convert_input_to_markdown_lines(input, {})

    if #markdown_lines < 1 or #markdown_lines[1] == 0 then
        return
    end

    ---TODO: add config
    ---@type vim.api.keyset.win_config
    local win_opt = { max_width = 80, max_height = 30, border = "rounded" }

    win_opt = vim.tbl_extend("keep", win_opt, {
        focusable = true,
        focus_id = "inaly-hint-label",
        close_events = { "CursorMoved", "CursorMovedI", "BufHidden" },
    })

    tooltip:init(markdown_lines)
end

---@param hint_list vim.lsp.inlay_hint.get.ret[]
function inlay_list_state:init(hint_list)
    inlay_list_state:clear()

    self.bufnr = api.nvim_create_buf(false, true)

    for _, value in ipairs(hint_list) do
        local label = value.inlay_hint.label
        if type(label) == "string" then
            self.labels_width = self.labels_width + #label
            table.insert(self.label_text_datas, { label })
            table.insert(self.label_raw_datas, { label })
        else
            for _, part in ipairs(label) do
                self.labels_width = self.labels_width + #part.value
                table.insert(self.label_text_datas, { part.value })
                table.insert(self.label_raw_datas, { part })
            end
        end
    end
    self.winnr = api.nvim_open_win(
        self.bufnr,
        true,
        { border = "rounded", relative = "cursor", width = self.labels_width, height = 1, row = 1, col = -1 }
    )
    set_win_buf_opt(self.winnr, self.bufnr)

    keymap("n", "q", function()
        self:close_hover()
    end, { buffer = self.bufnr, silent = true })
    keymap("n", "h", function()
        self:update(-1)
    end, { buffer = self.bufnr, silent = true })
    keymap("n", "l", function()
        self:update(1)
    end, { buffer = self.bufnr, silent = true })

    self.ns_id = api.nvim_create_namespace("inaly-ui")
    self.extmark_id = api.nvim_buf_set_extmark(self.bufnr, self.ns_id, 0, 0, {
        virt_text = self.label_text_datas,
        virt_text_pos = "inline",
    })
    self:update(1)
end

function inlay_list_state:close_hover()
    api.nvim_win_close(self.winnr, true)
    tooltip:close_hover()
end

---@return lsp.InlayHintLabelPart[]|string
function inlay_list_state:cur_part()
    return self.label_raw_datas[self.cur_inlay_idx]
end

---@param direct -1|1
function inlay_list_state:update(direct)
    if self.cur_inlay_idx == 0 then
        direct = 1
    else
        if direct == -1 then
            if self.cur_inlay_idx == 1 then
                return
            end
        elseif direct == 1 then
            if self.cur_inlay_idx == #self.label_text_datas then
                return
            end
        end
        table.remove(self.label_text_datas[self.cur_inlay_idx], 2)
    end

    self.cur_inlay_idx = self.cur_inlay_idx + direct
    table.insert(self.label_text_datas[self.cur_inlay_idx], self.ref_hi)

    self:refresh()

    tooltip:close_hover()

    self:handle_float()
end

function inlay_list_state:clear()
    self.winnr = nil
    self.bufnr = nil

    self.label_text_datas = {}
    self.labels_width = 0
    self.label_raw_datas = {}

    self.cur_inlay_idx = 0
    self.ns_id = nil
    self.extmark_id = nil
end

function inlay_list_state:refresh()
    api.nvim_buf_del_extmark(self.bufnr, self.ns_id, self.extmark_id)
    self.extmark_id = api.nvim_buf_set_extmark(self.bufnr, self.ns_id, 0, 0, {
        virt_text = self.label_text_datas,
        virt_text_pos = "inline",
    })
end

---@param hint_list vim.lsp.inlay_hint.get.ret[]
M.float_ui = function(hint_list)
    if #hint_list < 1 then
        return
    end

    inlay_list_state:init(hint_list)
end

---@param hint vim.lsp.inlay_hint.get.ret
M.req = function(hint)
    local client = lsp.get_clients({
        bufnr = hint.bufnr,
        client_id = hint.client_id,
        method = methods.textDocument_inlayHint,
    })[1]
    client:request(methods.inlayHint_resolve, hint.inlay_hint, lsp_handler, hint.bufnr)
end

return M
