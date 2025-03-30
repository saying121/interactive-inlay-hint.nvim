local api = vim.api
local lsp = vim.lsp
local methods = lsp.protocol.Methods
local lsp_util = lsp.util
local keymap = vim.keymap.set
-- local utils = require("interactive-inlay-hint.utils")

local M = {}

local auto_focus = true

local state = {
    ---@type integer
    winnr = nil,
    ---@type integer
    bufnr = nil,
    hover = {
        ---@type integer
        winnr = nil,
        ---@type integer
        bufnr = nil,

        categories = {
            ---@type integer
            winnr = nil,
            ---@type integer
            bufnr = nil,
            ---@type "tooltip"|"location"
            tooltip_location = nil,
        },
    },
}

local function close_hover()
    api.nvim_win_close(state.winnr, true)
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
    vim.print(part)

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
    vim.print(input)
    local markdown_lines = lsp_util.convert_input_to_markdown_lines(input or "", {})
    vim.print(markdown_lines)

    if #markdown_lines < 1 or #markdown_lines[1] == 0 then
        -- print("empty markdown lines")
        return
    end

    ---TODO: add config
    ---@type vim.lsp.util.open_floating_preview.Opts
    local win_opt = { max_width = 80, max_height = 30, border = "rounded" }

    local bufnr, winnr = lsp_util.open_floating_preview(
        markdown_lines,
        "markdown",
        vim.tbl_extend("keep", win_opt, {
            focusable = true,
            focus_id = "inaly-hint-label",
            close_events = { "CursorMoved", "CursorMovedI", "BufHidden" },
        })
    )

    api.nvim_create_autocmd("WinEnter", {
        callback = function()
            api.nvim_feedkeys(api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
        end,
        buffer = bufnr,
    })

    if auto_focus then
        api.nvim_set_current_win(winnr)

        api.nvim_feedkeys(api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
    end

    if state.winnr ~= nil then
        return
    end

    state.winnr = winnr
    keymap("n", "q", close_hover, { buffer = bufnr, silent = true })
    keymap("n", "<Esc>", close_hover, { buffer = bufnr, silent = true })

    vim.wo[winnr].signcolumn = "no"
end

---@param hint_list vim.lsp.inlay_hint.get.ret[]
function inlay_list_state:init(hint_list)
    inlay_list_state:clear()

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

    self.ns_id = api.nvim_create_namespace("inaly-ui")
    self.extmark_id = api.nvim_buf_set_extmark(state.bufnr, self.ns_id, 0, 0, {
        virt_text = self.label_text_datas,
        virt_text_pos = "inline",
    })
    self:update(1)
end

---@return lsp.InlayHintLabelPart[]|string
function inlay_list_state:cur_part()
    return self.label_raw_datas[self.cur_inlay_idx]
end

---@param direct -1|1
function inlay_list_state:update(direct)
    if self.cur_inlay_idx == 0 then
        direct = 1
    -- end
    elseif direct == -1 then
        if self.cur_inlay_idx == 1 then
            return
        end
        table.remove(self.label_text_datas[self.cur_inlay_idx], 2)
    elseif direct == 1 then
        if self.cur_inlay_idx == #self.label_text_datas then
            return
        end
        table.remove(self.label_text_datas[self.cur_inlay_idx], 2)
    end

    self.cur_inlay_idx = self.cur_inlay_idx + direct
    table.insert(self.label_text_datas[self.cur_inlay_idx], self.ref_hi)

    -- self:handle_float()

    self:refresh()
end

function inlay_list_state:show() end

function inlay_list_state:clear()
    self.label_text_datas = {}
    self.cur_inlay_idx = 0
    self.ns_id = nil
    self.extmark_id = nil
    self.labels_width = 0
end

function inlay_list_state:refresh()
    api.nvim_buf_del_extmark(state.bufnr, self.ns_id, self.extmark_id)
    self.extmark_id = api.nvim_buf_set_extmark(state.bufnr, self.ns_id, 0, 0, {
        virt_text = self.label_text_datas,
        virt_text_pos = "inline",
    })
end

---@param hint_list vim.lsp.inlay_hint.get.ret[]
M.float_ui = function(hint_list)
    if #hint_list < 1 then
        return
    end

    state.bufnr = api.nvim_create_buf(false, true)
    inlay_list_state:init(hint_list)

    state.winnr = api.nvim_open_win(
        state.bufnr,
        true,
        { border = "rounded", relative = "cursor", width = inlay_list_state.labels_width, height = 1, row = 1, col = 0 }
    )
    vim.wo[state.winnr].signcolumn = "no"
    vim.wo[state.winnr].number = false
    vim.wo[state.winnr].rnu = false

    -- inlay_list_state:show()

    keymap("n", "q", function()
        api.nvim_win_close(state.winnr, true)
    end, { buffer = state.bufnr, silent = true })
    keymap("n", "h", function()
        inlay_list_state:update(-1)
    end, { buffer = state.bufnr, silent = true })
    keymap("n", "l", function()
        inlay_list_state:update(1)
    end, { buffer = state.bufnr, silent = true })
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
