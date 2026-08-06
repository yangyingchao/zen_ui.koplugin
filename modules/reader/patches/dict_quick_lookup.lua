-- Zen UI: Icon-only DictQuickLookup buttons
-- Replaces the dictionary popup's text button row with a compact icon row.
-- Supports both old KOReader (DictButtonsReady event) and new KOReader
-- (buildButtonLayout override). When "show other items" is enabled,
-- unknown buttons are preserved as a text row.

local function apply()
    local DictQuickLookup = require("ui/widget/dictquicklookup")
    local logger = require("common/zen_logger").new("dict_quick_lookup")
    local _ = require("gettext")

    local _plugin_ref = rawget(_G, "__ZEN_UI_PLUGIN")

    local function is_enabled()
        local features = _plugin_ref
            and _plugin_ref.config
            and _plugin_ref.config.features
        return type(features) == "table" and features.dict_quick_lookup == true
    end

    local function allow_unknown()
        local cfg = _plugin_ref
            and _plugin_ref.config
            and _plugin_ref.config.highlight_lookup
        return type(cfg) == "table" and cfg.allow_unknown_items == true
    end

    -- IDs we handle explicitly; everything else is "unknown".
    -- assistant_* are the dict-popup buttons of assistant.koplugin; the Zen
    -- AI icon replaces them (see ai_dict_button).
    local KNOWN_IDS = {
        highlight = true, search = true, wikipedia = true,
        translate = true, close = true, save = true,
        vocabulary = true, prev_dict = true, next_dict = true,
        assistant_dictionary = true, assistant_wikipedia = true,
        assistant_term_xray = true,
    }

    -- Icon mapping for pool button ids.
    local ICON_MAP = {
        highlight = "lookup.highlight",
        search    = "lookup.search",
        wikipedia = "lookup.wikipedia",
        translate = "lookup.translate",
        close     = "close",
        prev_dict = "prev_dict",
        next_dict = "next_dict",
    }

    -- Build a minimal icon-only spec from an original button.
    local function icon_btn(orig, icon)
        if not orig then return nil end
        return {
            id            = orig.id,
            icon          = icon,
            enabled       = orig.enabled,
            enabled_func  = orig.enabled_func,
            callback      = orig.callback,
            hold_callback = orig.hold_callback,
        }
    end

    -- KOReader 2026.07 removed Translate from the default dictionary layout,
    -- while keeping the action in the button pool.
    local function translate_btn(dict_widget, orig)
        if orig then
            return icon_btn(orig, ICON_MAP.translate)
        end
        return {
            id = "translate",
            icon = ICON_MAP.translate,
            enabled = not dict_widget.isDocless or not dict_widget:isDocless(),
            callback = function()
                Translator:showTranslation(dict_widget.lookupword or dict_widget.word, true)
            end,
        }
    end

    -- Find the existing highlight index for the current selection (rolling docs).
    -- Returns nil if no match found.
    local function find_existing_highlight_index(highlight_module)
        local sel = highlight_module.selected_text
        if not sel or not sel.pos0 then return nil end
        local annotations = highlight_module.ui
            and highlight_module.ui.annotation
            and highlight_module.ui.annotation.annotations
        if not annotations then return nil end
        local is_rolling = highlight_module.ui.rolling ~= nil
        for i, item in ipairs(annotations) do
            if item.drawer then
                if is_rolling then
                    if item.pos0 == sel.pos0 and item.pos1 == sel.pos1 then
                        return i
                    end
                else
                    local p0, p1 = item.pos0, item.pos1
                    if p0 and p1
                        and p0.page == sel.pos0.page
                        and math.abs(p0.x - sel.pos0.x) < 2
                        and math.abs(p0.y - sel.pos0.y) < 2
                        and math.abs(p1.x - sel.pos1.x) < 2
                        and math.abs(p1.y - sel.pos1.y) < 2 then
                        return i
                    end
                end
            end
        end
        return nil
    end

    -- =========================================================================
    -- New KOReader API (buildButtonLayout exists)
    -- =========================================================================
    if DictQuickLookup.buildButtonLayout then
        local orig_buildButtonLayout = DictQuickLookup.buildButtonLayout

        DictQuickLookup.buildButtonLayout = function(self_dql)
            if not is_enabled() or self_dql.is_wiki_fullpage then
                return orig_buildButtonLayout(self_dql)
            end

            local buttons = orig_buildButtonLayout(self_dql)

            if self_dql.is_wiki then
                return buttons -- Wiki has its own layout, leave unchanged
            end

            -- Flatten all rows and index by id.
            local by_id = {}
            local unknown = {}
            for _i, row in ipairs(buttons) do
                for _j, btn in ipairs(row) do
                    if btn.id and KNOWN_IDS[btn.id] then
                        by_id[btn.id] = btn
                    elseif btn.id then
                        table.insert(unknown, btn)
                    end
                end
            end

            -- Build Zen icon row: highlight, [vocab], [wikipedia], translate, search.
            local icon_row = {}

            -- Close button, for left hand
            if by_id["close"] then
                table.insert(icon_row, icon_btn(by_id["close"], ICON_MAP.close))
            end

            -- Highlight button with toggle behavior.
            local h = by_id["highlight"]
            if h then
                local orig_cb = h.callback
                h.callback = function()
                    local idx = find_existing_highlight_index(self_dql.highlight)
                    if idx then
                        self_dql.highlight:deleteHighlight(idx)
                    else
                        orig_cb()
                    end
                    self_dql:onClose()
                end
                table.insert(icon_row, icon_btn(h, ICON_MAP.highlight))
            end

            -- Search.
            if by_id["search"] then
                table.insert(icon_row, icon_btn(by_id["search"], ICON_MAP.search))
            end

            -- Close button, for right hand
            if by_id["close"] then
                table.insert(icon_row, icon_btn(by_id["close"], ICON_MAP.close))
            end


            -- Reconstruct button layout.
            local result = {}
            if #icon_row > 0 then
                table.insert(result, icon_row)
            end

            -- Preserve unknown buttons as text rows when enabled.
            if allow_unknown() then
                for _i, btn in ipairs(unknown) do
                    if btn.id ~= "vocabulary" then
                        -- Put each unknown in its own row.
                        local found = false
                        for _j, row in ipairs(result) do
                            for _k, rb in ipairs(row) do
                                if rb.id == btn.id then found = true; break end
                            end
                            if found then break end
                        end
                        if not found then
                            table.insert(result, { btn })
                        end
                    end
                end
            end

            logger.dbg("new-api icon_row=",
                #icon_row, "unknown=", #unknown)
            return #result > 0 and result or buttons
        end

        logger.dbg("installed new-API buildButtonLayout override")
        return
    end
end

return apply
