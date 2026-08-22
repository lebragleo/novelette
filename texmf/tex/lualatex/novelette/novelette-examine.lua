-- This is file 'novelette-examine.lua', part of Novelette document class.
-- For Copyright and License, see accompanying file 'novelette.cls'.
-- File version: 2026-04-25. Pre-release.
-- Namespace: nvt

-- This file only loaded if \enable{examine} in draft mode. Loaded AtBeginDocument.

local DISC = node.id('disc')
local GLYPH = node.id('glyph')
local GLUE = node.id('glue')
local KERN = node.id('kern')
local RULE = node.id('rule')
local HLIST = node.id('hlist')
local VLIST = node.id('vlist')
local LPAR = node.id('local_par')
local MKERN = node.id('margin_kern')
local PENALTY = node.id('penalty')
local WHATSIT = node.id('whatsit')


-- Attribution: Code extracted/modified from file 'luatexbase.sty', 2015/10/04 v1.3.
-- Copyright (C) 2015-2025 The LaTeX Project. Released under terms of the LPPL.
-- Re-licensed to MIT License within Novelette:
nvt.base_callback=luatexbase.add_to_callback
function nvt.callback(name,fun,description,priority)
  local priority = priority
  if priority == nil then priority = #luatexbase.callback_descriptions(name) + 1 end
  local saved_callback={},ff,dd
  for k,v in pairs(luatexbase.callback_descriptions(name)) do
    if k >= priority then
      ff,dd= luatexbase.remove_from_callback(name, v) ; saved_callback[k]={ff,dd}
    end
  end
  nvt.base_callback(name,fun,description)
  for k,v in pairs(saved_callback) do nvt.base_callback(name,v[1],v[2]) end
  return
end
-- End code extracted/modified from 'luatexbase.sty'.


-- Attribution: Code extracted/modified from the 'luacolor' package,
-- Copyright 2007, 2009-2011 Heiko Oberdiek; 2016-2023 Oberdiek Package Support Group.
-- Released under terms of the LPPL. Re-licensed to MIT License within Novelette.
-- The essential code is wrapped in nvt.fromluacolor() to preserve local/global relationships.
function nvt.fromluacolor()
  local map = {n = 0,}
  function nvt.get(color) tex.write('' .. nvt.getvalue(color)) end
  function nvt.getvalue(color)
    local n = map[color]
    if not n then n = map.n + 1 ; map.n = n ; map[n] = color ; map[color] = n end
    return n
  end
  local attribute
  function nvt.setattribute(attr) attribute = attr end
  function nvt.getattribute() return attribute end
  local node_types = {
    [node.id("hlist")] = 1,
    [node.id("vlist")] = 1,
    [node.id("rule")]  = 4,
    [node.id("glyph")] = 4,
    [node.id("disc")]  = 3,
    [node.id("whatsit")] = {
      [node.subtype("pdf_colorstack")] =
        function(n)
          return n.stack == 0 and 5 or nil
        end,
      [node.subtype("special")] = 4,
      [node.subtype("pdf_literal")] = 4,
      [node.subtype("pdf_save")] = 4,
      [node.subtype("pdf_restore")] = 4,
    },
    [node.id("glue")] =
      function(n)
        if n.subtype >= 100 then
          if n.leader.id == RULE then return 4 else return 2 end
        end
      end,
  }
  local function get_type(n)
    local ret = node_types[n.id]
    if type(ret) == 'table' then ret = ret[n.subtype] end
    if type(ret) == 'function' then ret = ret(n) end
    return ret
  end
  local mode = 2
  local SPECIAL = node.subtype("special")
  local PDFLITERAL = node.subtype("pdf_literal")
  local DRY_FALSE = false
  local DRY_TRUE = true
  local function traverse(list, color, dry)
    if not list then return color end
    local head
    if get_type(list) == 1 then
      head = list.head
    elseif get_type(list) == 3 then
      head = list.replace
    else
      return color
    end
    for n in node.traverse(head) do
      local t = get_type(n)
      if t == 1 or t == 3 then
        color = traverse(n, color, dry)
      elseif t == 2 then
        local color_after = traverse(n.leader, color, DRY_TRUE)
        if color == color_after then
          traverse(n.leader, color, DRY_FALSE or dry)
        else
          traverse(n.leader, '', DRY_FALSE or dry)
          color = ''
        end
      elseif t == 4 then
        local v = node.has_attribute(n, attribute)
        if v then
          local newColor = map[v]
          if newColor ~= color then
            color = newColor
            if dry == DRY_FALSE then
              local newNode
              newNode = node.new(WHATSIT, PDFLITERAL)
              newNode.mode = mode
              newNode.data = color
              head = node.insert_before(head, n, newNode)
            end
          end
        end
      elseif t == 5 then
        color = ''
      end
    end
    if get_type(list) == 1 then list.head = head else list.replace = head end
    return color
  end
  if luatexbase.callbacktypes.pre_shipout_filter then
    luatexbase.add_to_callback('pre_shipout_filter', function(list)
      traverse(list, '', DRY_FALSE)
      return true
    end, 'nvt_psof')
  end
  if luaotfload.set_colorhandler then
    local set_attribute = node.direct.set_attribute
    luaotfload.set_colorhandler(function(head, n, color)
      set_attribute(n, attribute, nvt.getvalue(color))
      return head, n
    end)
  end
end
-- End code extracted/modified from 'luacolor'.
nvt.fromluacolor()
--


-- Attribution: Code copied or derived from code in file `lua-typo.sty', v.0.87,
-- Copyright © 2020-2024 by Daniel Flipo. See package 'lua-typo', included in TeXlive,
-- released under terms of the LPPL. Re-licensed to MIT License within Novelette.
--   Why not simply load 'lua-typo'? Reason: As with many (Lua)LaTeX packages,
-- that code addresses situations that will not appear in Novelette. But the chosen code
-- uses only what is necessary, and tightly integrates it with other Novelette code.
--   Overfull is not reported as typo, because it is always reported as warning.
-- End-of-line single letter is always prevented by penalty, so no need for typo single letter.
nvt = nvt or { } -- namespace
nvt.tbl = { }
nvt.map = { }
nvt.pagelist = ' '
nvt.failedlist = ' '
nvt.buf1 = 'Typographic flaws found in ' .. tex.jobname .. '.pdf.\n'
nvt.buf2 = 'Compiled ' .. nvt.now .. '.\n'
nvt.buf3 = 'Only OVERFULL is an error or warning. Rewrite!\n'
nvt.buf4 = 'WIDOW is a very serious flaw, unless intentional. Rewrite!\n'
nvt.buf5 = 'Other flaws show places where rewrite may improve appearance.\n'
nvt.buf6 = 'You decide what is important. No auto-fixes. Only rewrite can fix.\n\n'
nvt.buffer = nvt.buf1 .. nvt.buf2 .. nvt.buf3 .. nvt.buf4 .. nvt.buf5 .. nvt.buf6

local char_to_discard = { }
char_to_discard[string.byte(',')] = true
char_to_discard[string.byte('.')] = true
char_to_discard[string.byte('!')] = true
char_to_discard[string.byte('?')] = true
char_to_discard[string.byte(':')] = true
char_to_discard[string.byte(';')] = true
char_to_discard[string.byte('-')] = true

local eow_char = { }
eow_char[string.byte('.')] = true
eow_char[string.byte('!')] = true
eow_char[string.byte('?')] = true
eow_char[utf8.codepoint('…')] = true

local USRSKIP = 0
local PARSKIP = 3
local LFTSKIP = 8
local RGTSKIP = 9
local TOPSKIP = 10
local PARFILL = 15
local LINE = 1
local BOX = 2
local INDENT = 3
local ALIGN = 4
local USER = 0
local HYPH = 0x2D
local LIGA = 0x102
local parline = 0
local dimensions = node.dimensions
local rangedimensions = node.rangedimensions
local effective_glue = node.effective_glue
local set_attribute = node.set_attribute
local get_attribute = node.get_attribute
local slide = node.slide
local traverse = node.traverse
local traverse_id = node.traverse_id
local is_glyph  = node.is_glyph
local utf8_gsub = unicode.utf8.gsub

nvt.get_pagebody = function (head)
  local textht = tex.getdimen('textheight') ; local fn = head.list ; local body
  repeat fn = fn.next until fn.id == VLIST and fn.height > 0
  first = fn.list
  repeat
    for n in traverse_id(VLIST,first) do
      if n.subtype == 0 and n.height >= textht-1 then
        if n.height <= textht+8  then body = n ; break else first = n.list end
      end
    end
  until body or not first
  return body
end

nvt.graynode = function (node)
  local attr = nvt.getattribute()
  if node and node.id == DISC then
    local pre = node.pre ; local post = node.post ; local repl = node.replace
    if pre then set_attribute(pre,attr,GRAY) end
    if post then set_attribute(post,attr,GRAY) end
    if repl then set_attribute(repl,attr,GRAY) end
  elseif node then
    set_attribute(node,attr,GRAY)
  end
end

nvt.grayline = function (head)
  local first = head.head ; local map = nvt.map
  local graynode_if = function (node)
    local c = nvt.getattribute() ; local att = get_attribute(node,c) ; local black = true
    for i,v in ipairs (map) do
      if att == v then black = false ; break end
    end
    if black then nvt.graynode (node) end
  end
  for n in traverse(first) do
    if n.id == HLIST or n.id == VLIST then
      local ff = n.head
      for nn in traverse(ff) do
        if nn.id == HLIST or nn.id == VLIST then
          local f3 = nn.head
          for n3 in traverse(f3) do
            if n3.id == HLIST or n3.id == VLIST then
              local f4 = n3.head
              for n4 in traverse(f4) do
                if n4.id == HLIST or n4.id == VLIST then
                  local f5 = n4.head
                  for n5 in traverse(f5) do
                    if n5.id == HLIST or n5.id == VLIST then
                      local f6 = n5.head
                      for n6 in traverse(f6) do graynode_if(n6) end
                    else graynode_if(n5) end
                  end
                else graynode_if(n4) end
              end
            else graynode_if(n3) end
          end
        else graynode_if(nn) end
      end
    else graynode_if(n) end
  end
end

log_flaw= function (msg, line, colno, footnote)
  local pageno = tex.getcount('c@page') ; local prt ='p. ' .. pageno
  if colno then prt = prt .. ', col.' .. colno end
  if line then
    local l = string.format('%2d, ', line)
    if footnote then prt = prt .. ', (ftn.) line ' .. l else prt = prt .. ', line ' .. l end
  end
  prt =  prt .. msg ; nvt.buffer = nvt.buffer .. prt .. '\n'
end

local signature = function (node, string, swap)
  local n = node ; local str = string
  if n and n.id == GLYPH then
    local b = n.char
    if b and not char_to_discard[b] then
      if n.components then
        local c = ''
        for nn in traverse_id(GLYPH, n.components) do c = c .. utf8.char(nn.char) end
        if swap then str = str .. nvt.utf8_reverse(c) else str = str .. c end
      else
        str = str .. utf8.char(b)
      end
    end
  elseif n and n.id == DISC then
    local pre = n.pre ; local post = n.post ; local c1 = '' ; local c2 = ''
    if pre and pre.char then
      if pre.components then
        for nn in traverse_id(GLYPH, pre.components) do c1 = c1 .. utf8.char(nn.char) end
      else
        c1 = utf8.char(pre.char)
      end
      c1 = utf8_gsub(c1, '-', '')
    end
    if post and post.char then
      if post.components then
        for nn in traverse_id(GLYPH, post.components) do c2 = c2 .. utf8.char(nn.char) end
      else
        c2 = utf8.char(post.char)
      end
    end
    if swap then str = str .. nvt.utf8_reverse(c2) .. c1 else str = str .. c1 .. c2 end
  elseif n and n.id == GLUE then
    str = str .. '_'
  end
  local s = utf8_gsub(str, '_', '') ; local len = utf8.len(s)
  return len, str
end

local check_line_last_word = function (old, node, line, colno, flag, footnote)
  local match = false ; local new = '' ; local maxlen = 0
  if node then
    local swap = true ; local box, go ; local lastn = node
    while lastn and lastn.id ~= GLYPH and lastn.id ~= DISC and lastn.id ~= HLIST do
      lastn = lastn.prev
    end
    local n = lastn ; local words = 0
    while n and (words <= 2 or maxlen < 4) do
      if n and n.id == HLIST then
        box = n ; local first = n.head ; local lastn = slide(first) ; n = lastn
        while n do maxlen, new = signature (n, new, swap) ; n = n.prev end
        n = box.prev ; local w = utf8_gsub(new, '_', '')
        words = words + utf8.len(new) - utf8.len(w) + 1
      else
        repeat
          maxlen, new = signature (n, new, swap) ; n = n.prev
        until not n or n.id == GLUE or n.id == HLIST
        if n and n.id == GLUE then
          maxlen, new = signature (n, new, swap) ; words = words + 1 ; n = n.prev
        end
      end
    end
    new = nvt.utf8_reverse(new)
    new = utf8_gsub(new, '_+$', '')  -- $
    new = utf8_gsub(new, '^_+', '')
    maxlen = math.min(utf8.len(old), utf8.len(new))
    if flag and old ~= '' then
      local oldlast = utf8_gsub (old, '.*_', '') ; local newlast = utf8_gsub (new, '.*_', '')
      local oldsub = '' ; local newsub = ''
      local dlo = nvt.utf8_reverse(old) ; local wen = nvt.utf8_reverse(new)
      for p, c in utf8.codes(dlo) do
        local s = utf8_gsub(oldsub, '_', '')
        if utf8.len(s) < 4 then oldsub = utf8.char(c) .. oldsub end
      end
      for p, c in utf8.codes(wen) do
        local s = utf8_gsub(newsub, '_', '')
        if utf8.len(s) < 4 then newsub = utf8.char(c) .. newsub end
      end
      if oldsub == newsub then  match = true end
      if oldlast == newlast and utf8.len(newlast) >= 4 then
        if utf8.len(newlast) > 4 or not match then oldsub = oldlast ; newsub = newlast end
        match = true
      end
      if match then
        local k = utf8.len(newsub)
        local osub = nvt.utf8_reverse(oldsub) ; local nsub = nvt.utf8_reverse(newsub)
        while osub == nsub and k < maxlen do
          k = k + 1 ; osub = nvt.utf8_sub(dlo,1,k) ; nsub = nvt.utf8_sub(wen,1,k)
          if osub == nsub then newsub = nvt.utf8_reverse(nsub) end
        end
        newsub = utf8_gsub(newsub, '^_+', '')
        local msg = 'Consecutive lines with same ending: ' .. newsub
        log_flaw(msg, line, colno, footnote)
        local ns = utf8_gsub(newsub, '_', '')
        k = utf8.len(ns) ; oldsub = nvt.utf8_reverse(newsub) ; local newsub = ''
        local n = lastn ; local l = 0 ; local lo = 0 ; local li = 0
        while n and newsub ~= oldsub and l < k do
          if n and n.id == HLIST then
            local first = n.head
            for nn in traverse_id(GLYPH, first) do
              nvt.graynode(nn, GRAY)
              local c = nn.char ; if not char_to_discard[c] then l = l + 1 end
            end
          elseif n then
            nvt.graynode(n, GRAY)
            li, newsub = signature(n, newsub, swap) ; l = l + li - lo ; lo = li
          end
          n = n.prev
        end
      end
    end
  end
  return new, match
end

local check_line_first_word = function (old, node, line, colno, flag, footnote)
  local match = false ; local swap = false
  local new = '' ; local maxlen = 0 ; local n = node ; local box, go
  while n and n.id ~= GLYPH and n.id ~= DISC and (n.id ~= HLIST or n.subtype == INDENT) do
    n = n.next
  end
  start = n
  local words = 0
  while n and (words <= 2 or maxlen < 4) do
    if n and n.id == HLIST then
      box = n ; n = n.head
      while n do maxlen, new = signature (n, new, swap) ; n = n.next end
      n = box.next ; local w = utf8_gsub(new, '_', '')
      words = words + utf8.len(new) - utf8.len(w) + 1
    else
      repeat
        maxlen, new = signature (n, new, swap) ; n = n.next
      until not n or n.id == GLUE or n.id == HLIST
      if n and n.id == GLUE then
        maxlen, new = signature (n, new, swap) ; words = words + 1 ; n = n.next
      end
    end
  end
  new = utf8_gsub(new, '_+$', '') -- $
  new = utf8_gsub(new, '^_+', '')
  maxlen = math.min(utf8.len(old), utf8.len(new))
  if flag and old ~= '' then
    local oldfirst = utf8_gsub (old, '_.*', '') ; local newfirst = utf8_gsub (new, '_.*', '')
    local oldsub = '' ; local newsub = ''
    for p, c in utf8.codes(old) do
      local s = utf8_gsub(oldsub, '_', '')
      if utf8.len(s) < 4 then oldsub = oldsub .. utf8.char(c) end
    end
    for p, c in utf8.codes(new) do
      local s = utf8_gsub(newsub, '_', '')
      if utf8.len(s) < 4 then newsub = newsub .. utf8.char(c) end
    end
    if oldsub == newsub then match = true end
    if oldfirst == newfirst and utf8.len(newfirst) >= 4 then
      if utf8.len(newfirst) > 4 or not match then oldsub = oldfirst ; newsub = newfirst end
      match = true
    end
    if match then
      local k = utf8.len(newsub) ; local osub = oldsub ; local nsub = newsub
      while osub == nsub and k < maxlen do
        k = k + 1 ; osub = nvt.utf8_sub(old,1,k) ; nsub = nvt.utf8_sub(new,1,k)
        if osub == nsub then newsub = nsub end
      end
      newsub = utf8_gsub(newsub, '_+$', '')   --$
      local msg = 'Consecutive lines with same start: ' .. newsub
      log_flaw(msg, line, colno, footnote)
      local ns = utf8_gsub(newsub, '_', '')
      k = utf8.len(ns) ; oldsub = newsub ; local newsub = ''
      local n = start ; local l = 0 ; local lo = 0 ; local li = 0
      while n and newsub ~= oldsub and l < k do
        if n and n.id == HLIST then
          local nn = n.head
          for nnn in traverse(nn) do
            nvt.graynode(nnn, GRAY)
            local c = nn.char ; if not char_to_discard[c] then l = l + 1 end
          end
        elseif n then
          nvt.graynode(n, GRAY)
          li, newsub = signature(n, newsub, swap) ; l = l + li - lo ; lo = li
        end
        n = n.next
      end
    end
  end
  return new, match
end

local check_page_first_word = function (node, colno, footnote)
  local match = false ; local swap = false
  local new = '' ; local minlen = nvt.fontem ; local len = 0 ; local n = node ; local pn
  while n and n.id ~= GLYPH and n.id ~= DISC and (n.id ~= HLIST or n.subtype == INDENT) do
     n = n.next
  end
  local start = n
  if n and n.id == HLIST then start = n.head ; n = n.head end
  repeat
    len, new = signature (n, new, swap) ; n = n.next
  until len > minlen or (n and n.id == GLYPH and eow_char[n.char]) or
        (n and n.id == GLUE) or (n and n.id == KERN and n.subtype == 1)
  if n and (n.id == GLUE or n.id == KERN) then pn = n ; n = n.next end
  if len <= minlen and n and n.id == GLYPH and eow_char[n.char] then
    repeat n = n.next until not n or n.id == GLYPH or (n.id == GLUE and n.subtype == PARFILL)
    if n and n.id == GLYPH then match = true end
  end
  if match then
    local msg = 'Paragraph ends with short word: ' .. new
    log_flaw(msg, 1, colno, footnote)
    local n = start
    repeat nvt.graynode(n, GRAY) ; n = n.next until eow_char[n.char]
    nvt.graynode(n, GRAY)
  end
  return match
end

local show_pre_disc = function (disc)
  local n = disc
  while n and n.id ~= GLUE do nvt.graynode(n) ; n = n.prev end
  return n
  end

local footnoterule_ahead = function (head)
  local n = head ; local flag = false ; local totalht, ruleht
  if n and n.id == KERN and n.subtype == 1 then
    totalht = n.kern ; n = n.next
    while n and n.id == GLUE do n = n.next end
    if n and n.id == RULE and n.subtype == 0 then
      ruleht = n.height ; totalht = totalht + ruleht ; n = n.next
      if n and n.id == KERN and n.subtype == 1 then
        totalht = totalht + n.kern
        if totalht == 0 or totalht == ruleht then flag = true end
      end
    end
  end
  return flag
end

local check_EOP = function (node)
  local n = node ; local page_bot = false ; local body_bot = false
  while n and (n.id == GLUE or n.id == PENALTY or n.id == WHATSIT ) do n = n.next end
  if not n then
    page_bot = true ; body_bot = true
  elseif footnoterule_ahead(n) then
    body_bot = true
  end
  return page_bot, body_bot
end

local check_vbox = function (head, line, colno, vpos, lmax) -- Novelette columns.
  local vbflag  = false ; local l = 0 ; local ll = line ; local n = head.head
  while n do
    if n.id == HLIST and n.subtype == LINE then
      l = l + 1 ; if l > 1 then ll = ll + 1 end
      local first = n.head ; local linewd = n.width
      local hmax = linewd + tex.hfuzz ; local w,h,d = dimensions(1,2,0, first)
      local Stretch = 1.5
      if n.glue_set > Stretch and n.glue_sign == 1 and n.glue_order == 0 then
        vbflag = true ; nvt.grayline (n, GRAY)
        local s = string.format('%.1f%s', n.glue_set, 'x')
        local msg = 'Underfull line in column: stretch=' .. s .. ' max.'
        log_flaw(msg, ll, colno, false)
      end
    end
    n = n.next
  end
  lmax = math.max(l, lmax)
  return lmax, vbflag
end

check_vtop = function (top, colno, vpos)
  local head = top.list
  local PAGEmin = 5 ; local HYPHmax = 1 ; local Stretch = 1.5
  local LLminWD = 2*nvt.fontem ; local BackPI = nvt.fontem ; local BackFuzz = 0.1*nvt.fontem
  local blskip = tex.getglue('baselineskip') ; local vpos_min = PAGEmin*blskip* 1.5
  local linewd = tex.getdimen('textwidth')
  local first_bot = true ; local done  = false ; local footnote = false ; local ftnsplit = false
  local orphanflag = false ; local widowflag = false ; local pageshort = false
  local overfull = false ; local underfull = false ; local shortline = false
  local backpar = false ; local firstwd = '' ; local lastwd = ''
  local hyphcount = 0 ; local pageline = 0 ; local ftnline = 0 ; local line = 0 ; local bpmn = 0
  local body_bottom = false ; local page_bottom = false ; local pageflag = false
  local pageno = tex.getcount('c@page')
  while head do
    local nextnode = head.next
    if head.id == HLIST and head.subtype == LINE and (head.height > 0 or head.depth > 0) then
      vpos = vpos + head.height + head.depth ; done = true
      local linewd = head.width ; local first = head.head ; local ListItem = false
      if footnote then
        ftnline = ftnline + 1 ; line = ftnline
      else
        pageline = pageline + 1 ; line = pageline
      end
      page_bottom, body_bottom = check_EOP(nextnode)
      local hmax = linewd + tex.hfuzz ; local w,h,d = dimensions(1,2,0, first)
      if head.glue_set > Stretch and head.glue_sign == 1 and head.glue_order == 0 then
        pageflag = true ; underfull = true
        local s = string.format('%.1f%s', head.glue_set, 'x')
        local msg = 'Underfull line: stretch=' .. s .. ' max.'
        log_flaw(msg, line, colno, footnote)
      end
        if footnote and page_bottom then ftnsplit = true end
        while first.id == MKERN or (first.id == GLUE and first.subtype == LFTSKIP) do
          first = first.next
        end
        if first.id == LPAR then
          hyphcount = 0 ; firstwd = '' ; lastwd = ''
          if not footnote then
            parline = 1
            if pageline == 1 then
              local nn = first.next
              if nn.id == HLIST and nn.subtype == INDENT and nn.width > 0 then pageflag = true end
            end
            if body_bottom then orphanflag = true end
          end
          local nn = first.next
          if nn and nn.id == HLIST and nn.subtype == BOX then ListItem = true end
        elseif not footnote then
          parline = parline + 1
        end
        local flag = not ListItem and (line > 1)
      firstwd, flag = check_line_first_word(firstwd, first, line, colno, flag, footnote)
        if flag then pageflag = true end
        if pageline == 1 and parline > 1 and check_page_first_word(first, colno, footnote) then
          pageflag = true
        end
        local cn = first ; local lmax = 1
        repeat
          if cn.id == VLIST and cn.subtype == 0 then
            lmax, vbflag = check_vbox (cn, line, colno, vpos, lmax)
          end
          cn = cn.next
        until not cn
        if not footnote then
          line = line + lmax - 1 ; parline = parline + lmax - 1 ; pageline = pageline + lmax - 1
        end
        local ln = slide(first)
        if ln.id == RULE and ln.subtype == 0 then ln = ln.prev end
        local pn = ln.prev
        if pn and pn.id == GLUE and pn.subtype == PARFILL then
          hyphcount = 0 ; ftnsplit = false ; orphanflag = false
          if pageline == 1 and parline > 1 then widowflag = true end
          local PFskip = effective_glue(pn,head)
          local llwd = linewd - PFskip
          if llwd < LLminWD then
            pageflag = true ; shortline = true
            local msg = 'Short line: length=' .. string.format('%.0fpt', llwd/65536)
            log_flaw(msg, line, colno, footnote)
          end
          if PFskip < BackPI and PFskip >= BackFuzz and parline > 1 then
            pageflag = true ; backpar = true
            local msg = 'Nearly full line: backskip=' .. string.format('%.1fpt', PFskip/65536)
            log_flaw(msg, line, colno, footnote)
          end
          local flag = true
          if PFskip > BackPI or line == 1 then flag = false end
          local pnp = pn.prev
          lastwd, flag = check_line_last_word(lastwd, pnp, line, colno, flag, footnote)
          if flag then pageflag = true end
        elseif pn and pn.id == DISC then
          hyphcount = hyphcount + 1
          if hyphcount > HYPHmax then
            local pg = show_pre_disc (pn) ; pageflag = true
            local msg = 'Hyphens on consecutive lines.' ; log_flaw(msg, line, colno, footnote)
          end
          if (page_bottom or body_bottom) then
            pageflag = true ; local msg = 'Last word on page is hyphenated to next page.'
            log_flaw(msg, line, colno, footnote) ; local pg = show_pre_disc (pn)
          end
          local flag = true
          lastwd, flag = check_line_last_word(lastwd, pn, line, colno, flag, footnote)
          if flag then pageflag = true end
          if nextnode then
            local nn = nextnode.next ; local nnn = nil
            if nn and nn.next then
              nnn = nn.next
              if nnn.id == HLIST and nnn.subtype == LINE and nnn.glue_order == 2 then
                pageflag = true ; local msg = 'Next-to-last line of paragraph is hyphenated.'
                log_flaw(msg, line, colno, footnote) ; local pg = show_pre_disc (pn)
              end
            end
          end
        else
          hyphcount = 0
          if pn then
            local flag = true
            lastwd, flag = check_line_last_word(lastwd, pn, line, colno, flag, footnote)
            if flag then pageflag = true end
          end
        end
        if widowflag then
          pageflag = true ; local msg = 'WIDOW: Last line of paragraph at top of page.'
          log_flaw(msg, line, colno, footnote)
          if backpar or shortline or overfull or underfull then
            if backpar then backpar = false end
            if shortline then shortline = false end
            if overfull then overfull = false end
            if underfull then underfull = false end
          end
          nvt.grayline (head, GRAY) ; widowflag = false
        elseif orphanflag then
          pageflag = true ; local msg = 'Orphan: First line of paragraph at bottom of page.'
          log_flaw(msg, line, colno, footnote) ; nvt.grayline (head, GRAY)
        elseif ftnsplit then
          pageflag = true ; local msg = 'Footnote split across pages.'
          log_flaw(msg, line, colno, footnote) ; nvt.grayline (head, GRAY)
        elseif shortline then
          nvt.grayline (head, GRAY) ; shortline = false
        elseif overfull then
          nvt.grayline (head, GRAY) ; overfull = false
        elseif underfull then
          nvt.grayline (head, GRAY) ; underfull = false
        elseif backpar then
          nvt.grayline (head, GRAY) ; backpar = false
        end
      elseif head and head.id == HLIST and head.subtype == BOX then
        if head.width > 0 then
          if head.height == 0 then
            page_bottom, body_bottom = check_EOP(nextnode)
          else
            local hf = head.list
            if hf and hf.id == VLIST and hf.subtype == 0 then
              break
            else
              line = line + 1 ; pageline = pageline + 1
            end
          end
        end
        vpos = vpos + head.height + head.depth ; page_bottom, body_bottom = check_EOP (nextnode)
      elseif head.id==HLIST and (head.subtype==ALIGN) and (head.height > 0 or head.depth > 0) then
        vpos = vpos + head.height + head.depth
        if footnote then
          ftnline = ftnline + 1 ; line = ftnline
        else
          pageline = pageline + 1 ; line = pageline
        end
        page_bottom, body_bottom = check_EOP (nextnode)
        local wd = head.width ; local hmax = tex.getdimen('linewidth') + tex.hfuzz
        if wd > hmax then
          if head.subtype == ALIGN then
            local first = head.list
            for n in traverse_id(HLIST, first) do
              local last = slide(n.list)
              if last.id == GLUE and last.subtype == USER then wd = wd - effective_glue(last,n) end
            end
          end
        end
      elseif head and head.id == RULE and head.subtype == 0 then
        vpos = vpos + head.height + head.depth
        local prev = head.prev
        if body_bottom or footnoterule_ahead (prev) then
          footnote = true ; ftnline = 0 ; body_bottom = false ; orphanflag = false
          hyphcount = 0 ; firstwd = '' ; lastwd = ''
        end
      elseif body_bottom and head.id == GLUE and head.subtype == 0 then
        if first_bot then
          if pageline > 1 and pageline < PAGEmin and vpos < vpos_min then
            pageshort = true ; pageflag = true
            local msg = 'Short page: only ' .. pageline .. ' lines'
            log_flaw(msg, line, colno, footnote)
            local n = head
            repeat n = n.prev until n.id == HLIST and n.subtype == LINE
            nvt.grayline (n, GRAY)
          end
          first_bot = false
        end
      elseif head.id == GLUE then
        vpos = vpos + effective_glue(head,top)
      elseif head.id == KERN and head.subtype == 1 then
        vpos = vpos + head.kern
      elseif head.id == VLIST then
        vpos = vpos + head.height + head.depth
      end
      head = nextnode
    end
  if pageflag then
    local plist = nvt.pagelist ; local lastp = tonumber(string.match(plist, '%s(%d+),%s$'))
    if not lastp or pageno > lastp then
      nvt.pagelist = nvt.pagelist .. tostring(pageno) .. ', '
    end
  end
  return head, done
end

nvt.check_page = function (head)
  local pageno = tex.getcount('c@page') ; local body = nvt.get_pagebody(head)
  local textwd, textht, checked, boxed, top, first, next, n2, n3, col, colno
  local vpos = 0 ; local footnote = false ; local count = 0
  if body then
     top = body ; first = body.list
     textwd = tex.getdimen('textwidth') ; textht = tex.getdimen('textheight')
  end
  if ((first and first.id == HLIST and first.subtype == BOX) or
        (first and first.id == VLIST and first.subtype == 0)) and
        (first.width == textwd and first.height > 0 and not boxed) then
     top = body.list
     if first.id == VLIST then boxed = body end
  end
  while top do
    first = top.list ; next = top.next
    if top and top.id == VLIST and top.subtype == 0 and top.width > textwd/2 then
       local n, ok = check_vtop(top,colno,vpos)
       if ok then checked = true end
       if n then next = n end
    elseif (top and top.id == HLIST and top.subtype == BOX) and
           (first and first.id == VLIST and first.subtype == 0) and
           (first.height > 0 and first.width > 0) then
       colno = 0
       for col in traverse_id(VLIST, first) do
         colno = colno + 1 ; local n, ok = check_vtop(col,colno,vpos)
         if ok then checked = true end
       end
       colno = nil
       top = top.next
    elseif (top and top.id == HLIST and top.subtype == BOX) and
           (first and first.id == HLIST and first.subtype == BOX) and
           (first.height > 0 and first.width > 0) then
       colno = 0
       for n in traverse_id(HLIST, first) do
           colno = colno + 1 ; local col = n.list
           if col and col.list then
              local n, ok = check_vtop(col,colno,vpos)
              if ok then checked = true end
           end
       end
       colno = nil
    end
    if boxed and not next then next = boxed ; boxed = nil end
    top = next
  end
  if not checked then nvt.failedlist = nvt.failedlist .. tostring(pageno) .. ', ' end
  return true
end


-- End of file 'novelette-examine.lua'.
