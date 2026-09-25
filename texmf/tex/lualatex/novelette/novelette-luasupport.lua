-- This is file 'novelette-luasupport.lua', part of Novelette document class.
-- For Copyright and License, see accompanying file 'novelette.cls'.
-- File version: 2026-08-20.
-- Namespace: nvt prefix.

-- Instead of using elaborate LaTeX macros to parse settings, Novelette takes each setting,
-- then passes it to Lua. In the case of strings that may contain macro codes, the raw strings
-- may be expanded and/or detokenized before being sent to Lua. Here, the values
-- are sanity-checked. Bad values remain their defaults, if possible. Some values are calculated
-- in relation to other settings. The results are stored in Lua as variables, and passed back
-- to LaTeX as '\tmp...' numbers or strings. There, the '\tmp...' variables are converted to
-- LaTeX settings, typically '\def\nvt@..' form, or error/warning messages.
-- This strategy avoids complicated catcode changes.

-- In LaTeX, something such as 123.45 can be treated as a string or decimal number, because
-- LaTeX does not assign variable types. But Lua does assign variable types. Most (not all)
-- variables passed from LaTeX to Lua are received as strings, even if they look like a number.
-- Then Lua can change the variable type, and also fork depending on whether the change succeeds.

-- Without help, Lua only processes characters per-byte. That means that ASCII works well,
-- but UTF-8 needs help. Fortunately, there is a Lua unicode.utf8 library for that purpose.
-- The code relies on Lua 5.3+ for utf8 capabilities. It has been in luatex for many years.
if not (_VERSION >= 'Lua 5.3') then
  tex.sprint('\\makeatletter\\nvt@fatal{Your TeX installation is much too old. Cannot continue.}')
end
--

nvt = nvt or {} -- Namespace.
nvt.mode = nvt.mode or 'draft' -- Actually set before this file is read.
nvt.startmode = nvt.mode

-- Conversion of some useful length values to TeX pt
nvt.inch = 72.27
nvt.mm = 2.8452755876
--

-- Variables. These are the defaults. Quotes mean that the variable is a string, even if it looks
-- like a number. Without quotes, the variable is a number or a boolean.
nvt.subdocs = {} -- Holds path/filename for \subdoc call, to prevent cyclic error.
nvt.subdocs[1] = 'placeholder'
nvt.good = true -- Becomes false if error or warning. Once false, remains false.
nvt.title = 'Untitled Document'
nvt.author = 'Anonymous Author'
nvt.subtitle = ''
nvt.docdate = ''
nvt.now = nvt.now or '' -- Set in novelette.cls as nvt@now, then sent here. Format D:---
nvt.version = ''
nvt.lang = 'en'
nvt.nohyphens = false -- Becomes true if lang requests no hyphenation.
nvt.filepath = './'
nvt.pagestyle = 'marcen'
nvt.header = false
nvt.footer = true
nvt.lines = 35
nvt.misschars = 0 -- Counts number of missing characters.
nvt.overfull = 0 -- Counts overfull hboxes.
nvt.underfull = 0 -- Counts underfull hboxes.
nvt.misslist = '' -- List of missing characters, by Unicode.
nvt.trimwidth = 5.5*nvt.inch -- Default finished book interior page width,
nvt.trimheight = 5.5*nvt.inch -- and height.
nvt.trimtext = 'width=5.5in,height=8.5in' -- Changed unless mode=usl.
nvt.pagewidth = 5.5*nvt.inch -- Default PDFpage width, always same as trimwidth,
nvt.pageheight = 8.5*nvt.inch -- and height.
nvt.em = 12.05 -- Default font pt, usually changed by calculation.
nvt.bls = 14.46 -- Default baselineskip pt, usually changed by calculation.
nvt.linegap = 0 -- Calculated later. Normal text minimum gap from descender to next ascender.
nvt.charperline = 66 -- Estimated average characters (incl spaces) per line of text.
nvt.glue = 0.125*nvt.inch -- Width of glue strip, at spine.
nvt.moreglue = false -- If true, nvt.glue becomes larger.
nvt.minmargin = 0.5*nvt.inch -- This and following apply to default trimsize 5.5x8.5in.
nvt.evensidemargin = 0.5*nvt.inch
nvt.oddsidemargin = 0.625*nvt.inch
nvt.topmargin = 0.5*nvt.inch
nvt.textwidth = 3.875*nvt.inch
nvt.pdfx = true
nvt.oi = 'fogra'
nvt.examine = false
nvt.nopageflip = false
nvt.countnext = 0 -- Increments when \next used.
nvt.qq = 0 -- Counts bad use of " (double quotes).
nvt.notdef = 0  -- Increments when .notdef glyph appears.
nvt.todo = 0 -- Increments when \todo used.
nvt.clsvar = '' -- For experimental document class option.
nvt.luaerr = false -- Becomes true if lua error.
nvt.metric = false -- Becomes true if trimsize uses mm units. Once true, remains true.
nvt.pagelist = '' -- Might become nonempty when nvt.examine==true.
nvt.thisdoc = '' -- Becomes nonempty when compiling only subdoc files.
nvt.preamble = true -- Becomes false AtBeginDocument.
nvt.guide = 0 -- Becomes nonzero if guide enabled.
nvt.allfonts = 'main,dark,heavy,black,wide,thick,thin,srir,gero,plas,crge,'
nvt.usefont = {}
nvt.usefont['main'] = true ; nvt.usefont['dark'] = false ; nvt.usefont['heavy'] = false
nvt.usefont['black'] = false ; nvt.usefont['wide'] = false ; nvt.usefont['thick'] = false
nvt.usefont['thin'] = false ; nvt.usefont['srir'] = false ; nvt.usefont['gero'] = false
nvt.usefont['plas'] = false ; nvt.usefont['crge'] = false
nvt.space = {} -- em width of space character in font
nvt.space['main'] = 0.21 ; nvt.space['dark'] = 0.21 ; nvt.space['heavy'] = 0.21
nvt.space['black'] = 0.21 ; nvt.space['wide'] = 0.21 ; nvt.space['thick'] = 0.21
nvt.space['thin'] = 0.21 ; nvt.space['srir'] = 0.21 ; nvt.space['gero'] = 0.21
nvt.space['plas'] = 0.21 ; nvt.space['crge'] = 0.21
nvt.didstyle = {} -- true when its default style is set
nvt.styleleft = {} ; nvt.styleright = {} -- left and right fill
nvt.styletrack = {} -- tracking 0 - 9
nvt.stylefn = {} -- short font name
nvt.stylefont = {} -- nvt@ font name
nvt.stylecn = {} -- short case name
nvt.stylespace = {} -- em width of space character, depends on font
nvt.stylescale = {} -- font scale
nvt.styleraw = {} -- OpenType raw features
for i = 0, 9 do
  nvt.didstyle[i] = false
  nvt.styleleft[i] = '\\hfill'
  nvt.styleright[i] = '\\hfill'
  nvt.styletrack[i] = '2'
  nvt.stylefn[i] = 'main'
  nvt.stylefont[i] = '\\nvt@mainfont'
  nvt.stylecn[i] = 'none'
  nvt.styleraw[i] = 'RawFeature={+ss17}'
  nvt.stylespace[i] = 0.21
  nvt.stylescale[i] = 1
end
nvt.stylescale[1]=2 ; nvt.stylescale[2]=1.4 ; nvt.stylescale[3]=1.2 ; nvt.stylescale[4]=1.1
nvt.didtitle = false
nvt.didauthor = false
nvt.didsubtitle = false
nvt.didversion = false
nvt.diddocdate = false
nvt.didmode = false
nvt.didtrimsize = false
nvt.didlayout = false
nvt.didheadstyle = false
nvt.didscenestyle = false
nvt.didfootnotestyle = false
nvt.didversohead = false
nvt.didrectohead = false
local GLYPH = node.id('glyph')
local GLUE = node.id('glue')
local HLIST = node.id('hlist')
local VLIST = node.id('vlist')
--


-- Part of filter for removing "only floats" warning:
nvt.saysfloats = function (s)
  if string.find(s, 'only floats') then tex.sprint('\\def\\tmpsaysfloats{1}') end
end
--


-- Parse \sk:
nvt.parsesk = function (s)
  local n = tonumber(s) ; local k
  if n and n >= -10 and n <= 10 then
    k = n * 0.084
    tex.sprint('\\def\\tmpkern{' .. k .. '}') ; tex.sprint('\\def\\tmpreturn{1}')
  else
    tex.sprint('\\def\\tmpreturn{0}')
  end
end
--


-- Parse \image:
nvt.parseimage = function (star,opt,file) -----
  local a, t, f, l, lx, n ; local img = 0 ; local sc = 0 ; local label = 'image' ; local ok = true
  opt = string.gsub(opt, ' ', '') ; opt = opt .. ',' ; opt = string.gsub(opt, 'lines=', 'line=')

  if string.find(opt, 'scene,') then
     sc = 1 ; opt = string.gsub(opt, 'scene,', '') ; label = 'scene image'
  end
  tex.sprint('\\def\\tmpscene{' .. sc .. '}')
  if file ~= '' then
    label = string.gsub(file, '.*/', '')
    local e = utf8.len(label)
    if e > 32 then local b = utf8.offset(label, e - 32) ; label = string.sub(label, b, e) end
  end
  tex.sprint('\\def\\tmplabel{' .. label .. '}')
  file = string.gsub(file, ' ', '')
  if star == 'star' or nvt.mode == 'preview' or nvt.mode == 'final' then
    img = 1 ; if file == '' then img = 2 end
    local sp = string.gsub(file, '%s', '') ; if sp == '' then img = 2 end
    if string.find(file, '~') then img = 2 end
    if string.find(file, '%.%.') then img = 2 end
    if string.find(file, '\\') then img = 2 end
    if string.find(file, '//') then img = 2 end
    if string.find(file, ':') then img = 2 end
    if not string.find(file, '%.png$') then img = 2 end
    if 'link' == lfs.symlinkattributes(file, 'mode') then img = 2 end
    file = string.gsub(file, '^%./', '') -- remove initial ./ if present
    _, n = string.gsub(file, '/', '') ; if n > 5 then img = 2 end -- max 5 folder levels
    if img ~= 1 then ok = false end
  end
  tex.sprint('\\def\\tmpisfile{' .. img .. '}')
  if (nvt.mode == 'preview' or nvt.mode == 'final') and img == 1 then
    tex.sprint('\\def\\tmpvalidate{1}')
  end
  a, n = string.gsub(opt, '.*align=', '') ; a = string.gsub(a, ',.*', '')
  if n > 1 then ok = false end
  if a == 'center' then
    tex.sprint('\\def\\tmpalign{0}') ; opt = string.gsub(opt, 'align=center', '')
  elseif a == 'left' then
    tex.sprint('\\def\\tmpalign{1}') ; opt = string.gsub(opt, 'align=left', '')
  elseif a == 'right' then
    tex.sprint('\\def\\tmpalign{2}') ; opt = string.gsub(opt, 'align=right', '')
  end
  if n == 0 and sc == 1 then tex.sprint('\\def\\tmpalign{-1}') end
  if sc == 0 then
    t, n = string.gsub(opt, '.*tweak=', '') ; t = string.gsub(t, ',.*', '')
    if n > 1 then ok = false end
    if t == 'mid' then
      tex.sprint('\\def\\tmptweak{0}') ; opt = string.gsub(opt, 'tweak=mid','')
    elseif t == 'up' then
      tex.sprint('\\def\\tmptweak{1}') ; opt = string.gsub(opt, 'tweak=up','')
    elseif t == 'down' then
      tex.sprint('\\def\\tmptweak{2}') ; opt = string.gsub(opt, 'tweak=down','')
    end
    f, n = string.gsub(opt, '.*float=', '') ; f = string.gsub(f, ',.*','')
    if n > 1 then ok = false  end
    if f == 'none' then
      tex.sprint('\\def\\tmpfloat{0}') ; opt = string.gsub(opt, 'float=none', '')
    elseif f == 'here' then
      tex.sprint('\\def\\tmpfloat{1}') ; opt = string.gsub(opt, 'float=here', '')
    elseif f == 'top' then
      tex.sprint('\\def\\tmpfloat{2}') ; opt = string.gsub(opt, 'float=top', '')
    elseif f == 'bottom' then
      tex.sprint('\\def\\tmpfloat{3}') ; opt = string.gsub(opt, 'float=bottom', '')
    end
    if f == 'page' then -----
      tex.sprint('\\def\\tmplines{' .. (nvt.lines - 6) .. '}') ------
    else
      l, n = string.gsub(opt, '.*line=', '') ; l = string.gsub(l, ',.*', '')
      if n > 1 then ok = false end
      lx = l ; l = tonumber(l) -- tonumber may change format; preserve original as lx.
      if l and l == math.floor(l) and l > 1 and l <= nvt.lines then
        tex.sprint('\\def\\tmplines{' .. lx .. '}') ; opt = string.gsub(opt, 'line=' .. lx, '')
      else
        ok = false
      end
    end
    opt = string.gsub(opt, ',', '')
    if ok == true and opt == '' then
      tex.sprint('\\def\\tmpreturn{1}')
    else
      tex.sprint('\\def\\tmpreturn{0}') ; nvt.good = false
    end
  end
end
--


-- Parse \icon:
nvt.parseicon = function (star,file) -----
  local a, t, f, l, lx, n ; local img = 0 ; local ok = true
  file = string.gsub(file, ' ', '') -----
  if star == 'star' or nvt.mode == 'preview' or nvt.mode == 'final' then
    img = 1 ; if file == '' then img = 2 end
    local sp = string.gsub(file, '%s', '') ; if sp == '' then img = 2 end
    if string.find(file, '~') then img = 2 end
    if string.find(file, '%.%.') then img = 2 end
    if string.find(file, '\\') then img = 2 end
    if string.find(file, '//') then img = 2 end
    if string.find(file, ':') then img = 2 end
    if not string.find(file, '%.png$') then img = 2 end
    if 'link' == lfs.symlinkattributes(file, 'mode') then img = 2 end
    file = string.gsub(file, '^%./', '') -- remove initial ./ if present
    _, n = string.gsub(file, '/', '') ; if n > 5 then img = 2 end -- max 5 folder levels
    if img ~= 1 then ok = false end
  end
  tex.sprint('\\def\\tmpisfile{' .. img .. '}')
  if (nvt.mode == 'preview' or nvt.mode == 'final') and img == 1 then
    tex.sprint('\\def\\tmpvalidate{1}')
  end
  if ok == true then
    tex.sprint('\\def\\tmpreturn{1}')
  else
    tex.sprint('\\def\\tmpreturn{0}') ; nvt.good = false
  end
end
--


-- Check that a \subdoc call does not re-use same path/filename:
nvt.norepeatsubdoc = function (s)
  local n ; local ok = true
  s = string.gsub(s, ' ', '')
  local m = string.gsub(s, ':.*', '')
  local t = string.gsub(s, '^' .. m .. ':', '')
  local v = #nvt.subdocs
  for n = 1, v do
    if t == nvt.subdocs[n] then ok = false end
  end
  if ok == true then
    table.insert(nvt.subdocs, t) ; tex.sprint('\\def\\tmpt{}\\def\\tmpreturn{1}')
  else
    nvt.good = false ; tex.sprint('\\def\\tmpt{' .. t .. '}\\def\\tmpreturn{0}')
  end
end
--


-- Check that subdoc \thisdoc defines front|main|back matter in agreement with main document:
nvt.comparematter = function (s1, s2)
  s1 = string.gsub(s1, ' ', '') ; s2 = string.gsub(s2, ' ', '')
  s1 = string.gsub(s1, ':.*', '') ; tex.sprint('\\def\\tmpm{' .. s1 .. '}')
  if s1 == s2 then
    tex.sprint('\\def\\tmpreturn{1}')
  else
    tex.sprint('\\def\\tmpreturn{0}') ; nvt.good = false
  end
end
--


-- Parse subdoc file paths:
nvt.parsethisdoc = function (s)
  local p, f, d, m, n ; local ok = true
  s = string.gsub(s, ' ', '')
  if string.find(s, '%.%.') then ok = false end
  if string.find(s, '\\') then ok = false end
  if string.find(s, '//') then ok = false end
  _, n = string.gsub(s, ':', '') ; if n ~= 1 then ok = false end
  m = string.gsub(s, ':.*', '')
  if m == 'frontmatter' then tex.sprint('\\def\\tmpmatter{frontmatter}')
  elseif m == 'mainmatter' then tex.sprint('\\def\\tmpmatter{mainmatter}')
  elseif m == 'backmatter' then tex.sprint('\\def\\tmpmatter{backmatter}')
  elseif m == 'image' then tex.sprint('\\def\\tmpmatter{image}')
  else tex.sprint('\\def\\tmpmatter{unknown}') ; ok = false
  end
  s = string.gsub(s, '^' .. m .. ':', '') ; s = string.gsub(s, '^%./', '')
  if string.find(s, '^/') then ok = false end
  if not string.find(s, '%.tex$') then ok = false end
  f = string.gsub(s, '^%./', '')
  if 'link' == lfs.symlinkattributes(f, 'mode') then ok = false end
  _, n = string.gsub(s, '/', '') ; if n > 5 then ok = false end
  if n == 0 then d = ''
  elseif n == 1 then d = '../'
  elseif n == 2 then d = '../../'
  elseif n == 3 then d = '../../../'
  elseif n == 4 then d = '../../../../'
  elseif n == 5 then d = '../../../../../'
  else d = '' ; ok = false
  end
  p = string.gsub(s, '/' .. f .. '$', '')
  if ok == true then
    tex.sprint('\\def\\tmpthisdoc{' .. f .. '}')
    tex.sprint('\\def\\tmpthisdocpath{' .. p .. '}')
    tex.sprint('\\def\\tmpmaindocpath{' .. d .. '}')
    tex.sprint('\\def\\tmpreturn{1}')
  else
    nvt.good = false ; tex.sprint('\\def\\tmpreturn{0}')
  end
end
--


-- Parse \mode setting:
nvt.parsemode = function (s)
  if nvt.didmode == true then
    tex.sprint('\\def\\tmpreturn{-1}') ; nvt.good = false
  else
    s = string.gsub(s, ' ', '') ; s = string.gsub(s, ',', '')
    tex.sprint('\\begingroup\\makeatletter')
    if s == 'draft' then s = string.gsub(s, 'draft', '') end
    if s == 'preview' then
      s = string.gsub(s, 'preview', '')
      if s == '' then
        tex.sprint('\\gdef\\nvt@titleprefix{PREVIEW: }')
        tex.sprint('\\global\\\nvt@draftfalse\\global\\nvt@previewtrue')
        nvt.mode = 'preview' ; nvt.startmode = 'preview'
      end
    end
    if s == 'final' then
      s = string.gsub(s, 'final', '')
      if s == '' then
        tex.sprint('\\gdef\\nvt@titleprefix{}')
        tex.sprint('\\global\\\nvt@draftfalse\\global\\nvt@finaltrue')
        nvt.mode = 'final' ; nvt.startmode = 'final'
      end
    end
    if s == 'dev' then
      s = string.gsub(s, 'dev', '')
      if s == '' then
        tex.sprint('\\gdef\\nvt@titleprefix{DEV TEST: }')
        tex.sprint('\\global\\nvt@draftfalse\\global\\nvt@devtrue')
        nvt.mode = 'dev' ; nvt.startmode = 'dev'
      end
    end
    if s == 'usl' then
      s = string.gsub(s, 'usl', '')
      if s == '' then
        tex.sprint('\\gdef\\nvt@titleprefix{}')
        tex.sprint('\\global\\\nvt@draftfalse\\global\\nvt@usltrue')
        nvt.mode = 'usl' ; nvt.startmode = 'usl'
      end
    end
    tex.sprint('\\endgroup')
    if s == '' then
      tex.sprint('\\def\\tmpreturn{1}') ; nvt.didmode = true
    else
      nvt.good = false ; tex.sprint('\\def\\tmpreturn{0}')
    end
  end
end
--


-- Parse class option (usually empty):
nvt.parseclass = function (s)
  s = string.gsub(s, ' ', '') ; local ok = true
  if s ~= ''  and not string.find(s, '^var=')
    then ok = false
  else
    s = string.gsub(s, '^var=', '') ; nvt.clsvar = s
    tex.sprint('\\begingroup\\makeatletter\\gdef\\nvt@clsvar{' .. s .. '}\\endgroup')
  end
  if ok == true then
    tex.sprint('\\def\\tmpreturn{1}')
  else
    nvt.good = false ; tex.sprint('\\def\\tmpreturn{0}')
  end
end
--


-- Inspect typeset page for forbidden characters:
nvt.get_page_glyphs = function (h,n)
  local p = ' on PDFpage ' .. tex.getcount('c@page') .. '.'
  for t in node.traverse(h) do
    if t.id == HLIST or t.id == VLIST then nvt.get_page_glyphs(t.list,n+1) end
    if t.id == GLYPH then
      if t.char == 34 then -- \real{"} has different char code.
        texio.write_nl('! Problem: Double quotes' .. p .. '\n')
        nvt.qq = nvt.qq + 1 ; nvt.good = false
      elseif t.char == 43981 or t.char == 983040 or t.char == 65533 then
        nvt.notdef = nvt.notdef + 1
      elseif t.char ==  65532 then
        texio.write_nl('! Problem: TODO symbol' .. p)
        texio.write_nl('  You must replace it with some text, or remove it.\n')
        nvt.todo = nvt.todo + 1 ; nvt.good = false
      end
    end
  end
end
-- can also look for t.char=983040 (.notdef assigned to F0000) and related for FFFC and FFFD.
luatexbase.add_to_callback('pre_linebreak_filter',
  function(h)
    nvt.get_page_glyphs(h,0) 
    return true 
  end, 'my_page_glyphs')
--


-- Parse \headstyle:
nvt.parseheadstyle = function (s)
  s = s .. ',' ; s = string.gsub(s, ' ', '')
  local n, t, a, f, c, x, xx, min, max
  tex.sprint('\\begingroup\\makeatletter')
  if string.find(s, 'deco=') then -- only head chooses deco
    d, n = string.gsub(s, '.*deco=', '') ; d = string.gsub(d, ',.*', '')
    if n == 1 then
      if d == 'none' then
        s = string.gsub(s, 'deco=none', '') ; tex.sprint('\\gdef\\nvt@pndeco{}')
      elseif d == 'bar' then
        s = string.gsub(s, 'deco=bar', '') ; tex.sprint('\\gdef\\nvt@pndeco{|}')
      elseif d == 'bullet' then
        s = string.gsub(s, 'deco=bullet', '') ; tex.sprint('\\gdef\\nvt@pndeco{}')
      elseif d == 'square' then
        s = string.gsub(s, 'deco=square', '') ; tex.sprint('\\gdef\nvt@pndeco{}')
      elseif d == 'lozenge' then
        s = string.gsub(s, 'deco=lozenge', '') ; tex.sprint('\\gdef\\nvt@pndeco{}')
      elseif d == 'dash' then
        s = string.gsub(s, 'deco=dash', '') ; tex.sprint('\\gdef\\nvt@pndeco')
      end
    end
  end
  if string.find(s, 'track=') then
    t, n = string.gsub(s, '.*track=', '') ; t = string.gsub(t, ',.*', '')
    if n == 1 and t ~= '' then
      t = tonumber(t)
      if t and t >= 0 and t <= 9 then
        s = string.gsub(s, 'track=' .. t, '') ; tex.sprint('\\def\\tmptrack{' .. t .. '}')
      end
    end
  end
  if string.find(s, 'font=') then
    f, n = string.gsub(s, '.*font=', '') ; f = string.gsub(f, ',.*', '')
    f = string.gsub(f, ',', '')
    if n == 1 then
      if string.find(nvt.allfonts, f) then ----- don't forget the space value
        s = string.gsub(s, 'font=' .. f, '')
        tex.sprint('\\gdef\\nvt@headfont{\\nvt@' .. f .. '}' )
        tex.sprint('\\gdef\\nvt@headfn{' .. f .. '}\\global\\nvt@use' .. f .. 'true')
      end
    end
  end
  if string.find(s, 'scale=') then ----- needs default. apply scale to case
    x, n = string.gsub(s, '.*scale=', '') ; x = string.gsub(x, ',.*', '')
    if n == 1 and x ~= '' then
      xx = '' .. x -- because tonumber may add preceding 0.
      x = tonumber(x)
      if x and x >= 0.83 and x <= 1 then
        tex.sprint('\\gdef\\nvt@headscale{' .. x .. '}') -- not needed. apply to case feat
        s = string.gsub(s, 'scale=' .. xx, '')
      end
    end
  end
  if string.find(s, 'case=') then
    c, n = string.gsub(s, '.*case=', '') ; c = string.gsub(c, ',.*', '')
    s = string.gsub(s, 'title', 'titl')
    if n == 1 then ----- becomes nvt@headfeat
      if c == 'none' then
        s = string.gsub(s, 'case=none', '') ; tex.sprint('\\gdef\\nvt@headfeat{}')
        tex.sprint('\\gdef\\nvt@pnfeat{}')
      end
      if c == 'smcp' then
        s = string.gsub(s, 'case=smcp', '')
        tex.sprint('\\gdef\\nvt@headfeat{}') -----
        tex.sprint('\\gdef\\nvt@pnfeat{}') -----
      end
      if c == 'onum' then
        s = string.gsub(s, 'case=onum', '')
        tex.sprint('\\gdef\\nvt@headfeat{}') -----
        tex.sprint('\\gdef\\nvt@pnfeat{}') -----
      end
      if c == 'smon' then
        s = string.gsub(s, 'case=smon', '')
        tex.sprint('\\gdef\\nvt@headfeat{}') -----
        tex.sprint('\\gdef\\nvt@pnfeat{}') -----
      end
      if c == 'titl' then
        s = string.gsub(s, 'case=titl', '')
        tex.sprint('\\gdef\\nvt@headfeat{}') -----
        tex.sprint('\\gdef\\nvt@pnfeat{}') -----
      end
      if c == 'dflt' then
        s = string.gsub(s, 'case=dflt', '')
        tex.sprint('\\gdef\\nvt@headfeat{}') -----
        tex.sprint('\\gdef\\nvt@pnfeat{}') -----
      end
    end
  end
  s = string.gsub(s, ',', '')
  tex.sprint('\\endgroup')
  if s == '' then
    tex.sprint('\\def\\tmpreturn{1}')
  else
    tex.sprint('\\def\\tmpreturn{0}') ; nvt.good = false
  end
end
--


-- Parse \setstyleN for N = 0-9:
nvt.parsesetstyle = function (N, s) -- style number, setting
  s = s .. ',' ; s = string.gsub(s, ' ', '')
  local n, m, mm, mmm, t, tt, a, f, c, h, d ; local ok = true
  N = tonumber(N) ; if not N or N < 0 or N > 1 then ok = false end
  if nvt.didstyle[N] == true then ok = false else nvt.didstyle[N] = true end
  if nvt.preamble == false then ok = false end
  if ok == true and string.find(s, 'scale=') then
    m, n = string.gsub(s, '.*scale=', '') ; m = string.gsub(m, ',.*', '') ; mm = m
    if n == 1 and m ~= '' then
      m = tonumber(m)
      if m and m >= 1 and m <= 4 then
        s = string.gsub(s, 'scale=' .. mm, '') ; nvt.stylescale[N] = mm
      end
    end
  end
  if ok == true and string.find(s, 'align=') then
    a, n = string.gsub(s, '.*align=', '') ; a = string.gsub(a, ',.*', '')
    if n == 1 then
      if (a == 'left' or a == 'right' or a == 'center') then
        s = string.gsub(s, 'align=' .. a, '')
      end
      if a == 'left' then
        string.gsub(s, 'align=left', '')
        nvt.styleleft[N] = '' ; nvt.styleright[N] = '\\hfill'
      elseif a == 'right' then
        string.gsub(s, 'align=right', '')
        nvt.styleleft[N] = '\\hfill' ; nvt.styleright[N] = ''
      elseif a == 'center' then
        string.gsub(s, 'align=center', '')
        nvt.styleleft[N] = '\\hfill' ; nvt.styleright[N] = '\\hfill'
      end
    end
  end
  if ok == true and string.find(s, 'track=') then
    t, n = string.gsub(s, '.*track=', '') ; t = string.gsub(t, ',.*', '') ; tt = t
    if n == 1 and t ~= '' then
      t = tonumber(t)
      if t and t >= 0 and t <= 9 then
        s = string.gsub(s, 'track=' .. t, '') ; nvt.styletrack[N] = tt
      end
    end
  end
  if ok == true and string.find(s, 'font=') then
    f, n = string.gsub(s, '.*font=', '') ; f = string.gsub(f, ',.*', '')
    f = string.gsub(f, ',', '')
    if n == 1 then
      if string.find(nvt.allfonts, f) then
        tex.sprint('\\begingroup\\makeatletter\\global\\nvt@use' .. f .. 'true\\endgroup')
        s = string.gsub(s, 'font=' .. f, '')
        if f == 'main' then
          nvt.stylefn[N] = 'main' ; nvt.stylefont[N] = '\\normalfont'
        else
          nvt.stylefn[N] = f ; nvt.stylefont[N] = '\\nvt@' .. f
        end
        local ff = "'" .. f .. "'" ; nvt.stylespace[N] = nvt.space[ff] ; nvt.usefont[ff] = true
      end
    end
  end
  if ok == true and string.find(s, 'case=') then
    c, n = string.gsub(s, '.*case=', '') ; c = string.gsub(c, ',.*', '')
    c = string.gsub(c, 'title', 'titl')
    if n == 1 then
      if c == 'none' then
        nvt.stylecn[N] = 'none' ; s = string.gsub(s, 'case=none', '')
        nvt.styleraw[N] = 'RawFeature={+ss17}'
      elseif c == 'smcp' then
        nvt.stylecn[N] = 'smcp' ; s = string.gsub(s, 'case=smcp', '')
        nvt.styleraw[N] = 'RawFeature={+smcp,+ss17}'
      elseif c == 'onum' then
        nvt.stylecn[N] = 'onum' ; s = string.gsub(s, 'case=onum', '')
        nvt.styleraw[N] = 'RawFeature={+onum,+ss17}'
      elseif c == 'smon' then
        nvt.stylecn[N] = 'smon' ; s = string.gsub(s, 'case=smon', '')
        nvt.styleraw[N] = 'RawFeature={+smcp,+onum,+ss17}'
      elseif c == 'titl' then
        nvt.stylecn[N] = 'titl' ; s = string.gsub(s, 'case=titl', '')
        nvt.styleraw[N] = 'RawFeature={+titl,+ss17}'
      end
    end
  end
  s = string.gsub(s, ',', '')
  if s == '' and ok == true then
    tex.sprint('\\def\\tmpreturn{1}')
  else
    tex.sprint('\\def\\tmpreturn{0}') ; nvt.good = false
  end
end
--


-- Parse \styleN for N = 0-9:
nvt.parsestyle = function (N, s) -- style number, option
  s = string.gsub(s, ' ', '')
  local h, d
  if s == 'info' then
    tex.sprint('\\def\\tmpinfo{1}') ; s = string.gsub(s, 'info', '')
  else
    tex.sprint('\\def\\tmpinfo{0}')
  end
  N = tonumber(N)
  if (not N or N < 0 or N > 9) then
    tex.sprint('\\def\\tmpreturn{0}') ; nvt.good = false
  else
    tex.sprint('\\def\\tmpscale{' .. nvt.stylescale[N] .. '}')
    h = nvt.stylescale[N] * nvt.bls
    d = 0.3 * nvt.stylescale[N] * nvt.bls
    tex.sprint('\\def\\tmph{' .. h .. 'pt}\\def\\tmpd{' .. d .. 'pt}')
    tex.sprint('\\def\\tmpleft{' .. nvt.styleleft[N] .. '}')
    tex.sprint('\\def\\tmpright{' .. nvt.styleright[N] .. '}')
    tex.sprint('\\def\\tmptrack{' .. nvt.styletrack[N] .. '}')
    tex.sprint('\\def\\tmpfn{' .. nvt.stylefn[N] .. '}')
    tex.sprint('\\begingroup\\makeatletter\\gdef\\tmpfont{' .. nvt.stylefont[N] .. '}\\endgroup')
    tex.sprint('\\def\\tmpspace{' .. nvt.space[nvt.stylefn[N]] .. '}')
    tex.sprint('\\def\\tmpraw{' .. nvt.styleraw[N] .. '}')
    if s == '' then
      tex.sprint('\\def\\tmpreturn{1}')
    else
      tex.sprint('\\def\\tmpreturn{0}') ; nvt.good = false
    end
    if nvt.preamble == true then tex.sprint('\\def\\tmpreturn{-99}') end
  end
end
--


-- Parse \line argument:
nvt.parseline = function (s)
  s = string.gsub(s, ' ', '') ; s = s .. ',' ; s = string.gsub(s, 'thickness', 'thick')
  local n, a, w, t, tt, d
  if string.find(s, 'align=') then
    a, n = string.gsub(s, '.*align=', '') ; a = string.gsub(a, ',.*', '')
    if n == 1 and a == 'left' then
      tex.sprint('\\def\\tmpleft{}\\def\\tmpright{\\hfill}')
      s = string.gsub(s, 'align=left', '')
    elseif n == 1 and a == 'right' then
      tex.sprint('\\def\\tmpleft{\\hfill}\\def\\tmpright{}')
      s = string.gsub(s, 'align=right', '')
    elseif n == 1 and a == 'center' then
      tex.sprint('\\def\\tmpleft{\\hfill}\\def\\tmpright{\\hfill}')
      s = string.gsub(s, 'align=center', '')
    end
  end
  if string.find(s, 'width=') then
    w, n = string.gsub(s, '.*width=', '') ; w = string.gsub(w, ',.*', '')
    if n == 1 and string.find(w, 'em$') then
      w = string.gsub(w, 'em$', '') ; ww = tonumber(w)
      if ww and ww >= 0 then
        s = string.gsub(s, 'width=' .. w .. 'em', '')
        if ww * nvt.em < nvt.textwidth then
          tex.sprint('\\def\\tmpwidth{' .. w .. 'em }')
        end
      end
    end
  end
  if string.find(s, 'thick=') then
    t, n = string.gsub(s, '.*thick=', '') ; t = string.gsub(t, ',.*', '')
    tt = tonumber(t)
    if tt then
      s = string.gsub(s, 'thick=' .. t, '')
      if tt == 0 then
        tex.sprint('\\def\\tmpshow{0}')
      else
        if tt < 1 then tt = 1 end
        if tt > 9 then tt = 9 end
        tt = 0.76 + 0.655 * (tt - 1)
        tex.sprint('\\def\\tmpthick{' .. tt .. 'pt }')
      end
    end
  end
  d = -0.2 * nvt.bls + 0.5 * tt -----
  tex.sprint('\\def\\tmpdrop{' .. d .. 'pt}')
  s = string.gsub(s, ',', '')
  if s == '' then
    tex.sprint('\\def\\tmpreturn{1}')
  else
    tex.sprint('\\def\\tmpreturn{0}') ; nvt.good = false
  end
end
--


-- Parse \scene option:
nvt.parsescene = function (s)
  s = string.gsub(s, ' ', '') ; s = string.gsub(s, ',', '')
  local n, a
  if string.find(s, 'align=') then
    a, n = string.gsub(s, '.*align=', '')
    if n == 1 then
      if a == 'center' then
        tex.sprint('\\def\\tmpsceneleft{\\hfill}\\gdef\\tmpsceneright{\\hfill}')
        s = string.gsub(s, 'align=center', '')
      elseif a == 'left' then
        tex.sprint('\\def\\tmpsceneleft{}\\gdef\\tmpsceneright{\\hfill}')
        s = string.gsub(s, 'align=left', '')
      elseif a == 'right' then
        tex.sprint('\\def\\tmpsceneleft{\\hfill}\\gdef\\tmpsceneright{}')
        s = string.gsub(s, 'align=right', '')
      end
    end
  end
  if s == '' then
    tex.sprint('\\def\\tmpreturn{1}')
  else
    tex.sprint('\\def\\tmpreturn{0}') ; nvt.good = false
  end
  if nvt.preamble == true then tex.sprint('\\def\\tmpreturn{-99}') end
end
--


-- Parse \scenestyle:
nvt.parsescenestyle = function (s)
  s = s .. ',' ; s = string.gsub(s, ' ', '') ; s = string.gsub(s, ',', '')
  local n, t, a, f, c, x, xx, ok ; local miss = ''
  local min = 1 ; local max = 1.5
  if nvt.didscenestyle == true then ok = false else nvt.didscenestyle = true ; ok = true end
  if nvt.preamble == false then ok = false end
  tex.sprint('\\begingroup\\makeatletter')
  if ok == true and string.find(s, 'align=') then
    a, n = string.gsub(s, '.*align=', '') ; a = string.gsub(a, ',.*', '')
    if n == 1 then
      if a == 'center' then
        tex.sprint('\\gdef\\nvt@sceneleft{\\hfill}\\gdef\\nvt@sceneright{\\hfill}')
        s = string.gsub(s, 'align=center', '')
      elseif a == 'left' then
        tex.sprint('\\gdef\\nvt@sceneleft{}\\gdef\\nvt@sceneright{\\hfill}')
        s = string.gsub(s, 'align=left', '')
      elseif a == 'right' then
        tex.sprint('\\gdef\\nvt@sceneleft{\\hfill}\\gdef\\nvt@sceneright{}')
        s = string.gsub(s, 'align=right', '')
      end
    end
  end
  tex.sprint('\\endgroup')
  if s == '' then
    tex.sprint('\\def\\tmpreturn{1}')
  else
    tex.sprint('\\def\\tmpreturn{0}') ; nvt.good = false
  end
end
--


-- Parse \footnotestyle:
nvt.parsefnstyle = function (s)
  local ok = false
  if nvt.didfootnotestyle == true then
    tex.sprint('\\def\\tmpreturn{-1}') ; nvt.good = false
  else
    tex.sprint('\\begingroup\\makeatletter')
    s = string.gsub(s, ' ', '') ; s = string.gsub(s, ',', '') ; s = string.gsub(s, 'indent=', '')
    if s == 'none' then ok = true ; tex.sprint('\\gdef\\nvt@fnindent{0}') end
    if s == 'away' then ok = true ; tex.sprint('\\gdef\\nvt@fnindent{1}') end
    if s == 'both' then ok = true ; tex.sprint('\\gdef\\nvt@fnindent{2}') end
    if s == 'near' or s == '' then ok = true ; tex.sprint('\\gdef\\nvt@fnindent{3}') end
    nvt.didfootnotestyle = true
    tex.sprint('\\endgroup')
    if ok == true then
      tex.sprint('\\def\\tmpreturn{1}')
    else
      tex.sprint('\\def\\tmpreturn{0}') ; nvt.good = false
    end
  end
end
--


-- From 'lua-typo' by Daniel Flipo:
nvt.utf8_reverse = function (s)
  if utf8.len(s) > 1 then
    local so = ''
    for p, c in utf8.codes(s) do so = utf8.char(c) .. so end
    s = so
  end
  return s
end
nvt.utf8_sub = function (s,i,j)
  i = utf8.offset(s,i) ; j = utf8.offset(s,j+1) - 1
  return string.sub(s,i,j)
end
--


-- Count missing characters, and flag bad. Hat tip to user 'wipet'.
-- Note that an explicit \char"FFFD does not trigger this, because all Novelette fonts have it:
luatexbase.add_to_callback('glyph_not_found', function(id,char)
  local tc, tcu, tc2, tc3, sc ; nvt.good = false
  tcu = string.format('%s U+%.4X', utf8.char(char), char) ; tc = string.gsub(tcu, '.*U%+', '')
  tc2 = string.gsub(tc,'..$','') ; tc3 = string.gsub(tc,'^..','') ; tc3 = string.gsub(tc3,'.$','')
  local su = string.format('U+%.4X', char) ; local sun = string.format('%.4X', char)
  local sf = string.format('%s (U+%.4X)', utf8.char(char), char)
  if tc2=='02' and string.find('BCDEF',tc3) then
    sc = 'Combining diacritical mark ' .. sf .. ' unavailable.\n'
      .. '  Characters with diacriticals are pre-composed in Novelette fonts.'
  elseif tc2 == '03' and string.find('0123456',tc3) then
    sc = 'Combining diacritical mark ' .. sf .. ' unavailable.\n'
      .. '  Characters with diacriticals are pre-composed in Novelette fonts.'
  else
    sc = 'Character ' .. sf .. ' unavailable in Novelette fonts.'
  end
  texio.write_nl('! Problem: ' .. sc .. '\n')
  nvt.misschars = nvt.misschars + 1
  if not string.find(nvt.misslist, sun) then
    if nvt.misschars < 9 then
      nvt.misslist = nvt.misslist .. ' ' .. su
    else
      nvt.misslist = nvt.misslist .. ' and others.'
    end
  end
end, 'miss_chars')
--


-- Validate image file:
function nvt.validateimage (s)
  local ok = true
-----
  if ok == true then
    tex.sprint('\\def\\tmpvalid{1}')
  else
    nvt.good = false ; tex.sprint('\\def\\tmpvalid{0}')
  end
end
--


-- Parse \entry option:
function nvt.parseentry (s)
  s = string.gsub(s,' ','') ; if s == '' then s = 0 end
  s = tonumber(s) or -1
  if (s < 0) or (s > 2) then s = -1 end
  tex.sprint('\\def\\tmppad{' .. s .. '}') ; if s == -1 then nvt.good = false end
end
--


-- Parse option of block environment:
function nvt.parseblock (s,d)
  local n, size, a, l, r, ln, rn
  s = string.gsub(s, ' ', '') ; s = s .. ','
  size, n = string.gsub(s, '.*size=', '') ; size = string.gsub(size, ',.*', '')
  if n == 1 then
    if d == "D" then
      if size == 'normal' then
        tex.sprint('\\def\\tmpblocksize{0}') ; s = string.gsub(s, 'size=normal', '')
      elseif size == 'small' then
        tex.sprint('\\def\\tmpblocksize{1}') ; s = string.gsub(s, 'size=small', '')
        local t = 0.125 * nvt.em ; tex.sprint('\\def\\tmpsmtop{' .. t .. 'pt}')
      end
    else
      if size == 'small' then tex.sprint('\\def\\tmpblocksize{-2}') end
    end
  else
    tex.sprint('\\def\\tmpblocksize{0}')
  end
  a, n = string.gsub(s, '.*align=', '') ; a = string.gsub(a, ',.*', '')
  if n == 1 then
    if a == 'justify' then
      tex.sprint{'\\def\\tmpblockalign{0}'} ; s = string.gsub(s, 'align=justify', '')
    elseif a == 'center' then
      tex.sprint{'\\def\\tmpblockalign{1}'} ; s = string.gsub(s, 'align=center', '')
    elseif a == 'left' then
      tex.sprint{'\\def\\tmpblockalign{2}'} ; s = string.gsub(s, 'align=left', '')
    elseif a == 'right' then
      tex.sprint{'\\def\\tmpblockalign{3}'} ; s = string.gsub(s, 'align=right', '')
    end
  else
    tex.sprint('\\def\\tmpblockalign{0}')
  end
  s = string.gsub(s, ',', '')
  _, n = string.gsub(s, '/', '')
  if n == 1 then
    l = string.gsub(s, '/.*', '') ; ln = tonumber(l)
    r = string.gsub(s, '.*/', '') ; rn = tonumber(r)
    if l == 'k' and r == 'k' then
      tex.sprint('\\def\\tmpblockleft{-99}\\def\\tmpblockright{-99}')
      s = string.gsub(s, 'k/k', '')
    elseif l == 'k' and rn and rn >= 0 and rn <= 8 then
      tex.sprint('\\def\\tmpblockleft{-99}\\def\\tmpblockright{' .. r .. '}')
      s = string.gsub(s, 'k/' .. r, '')
    elseif r == 'k' and ln and ln >= 0 and ln <= 8 then
      tex.sprint('\\def\\tmpblockleft{' .. l .. '}\\def\\tmpblockright{-99}')
      s = string.gsub(s, l .. '/k', '')
    elseif ln and rn and ln >= 0 and rn >= 0 and ln <= 8 and rn <= 8 then
      tex.sprint('\\def\\tmpblockleft{' .. l .. '}\\def\\tmpblockright{' .. r .. '}')
      s = string.gsub(s, l .. '/' .. r, '')
    else
      tex.sprint('\\def\\tmpblockleft{2}\\def\\tmpblockright{0}')
    end
  end
  if s == '' then
    tex.sprint('\\def\\tmpreturn{1}')
  else
    nvt.good = false ; tex.sprint('\\def\\tmpreturn{0}')
  end
end
--


-- Parse option of component environment:
function nvt.parsecomponent (s1,s2)
  s1 = string.gsub(s1, ' ', '') ; s1 = s1 .. ','
  tex.sprint('\\def\\tmpguide{' .. nvt.guide .. '}')
  if string.find(s1, 'legal,') then
    tex.sprint('\\def\\tmplegal{1}\\def\\tmprecto{0}\\def\\tmpsingle{1}')
    tex.sprint('\\def\\tmptps{empty}\\def\\tmpguide{0}')
    s1 = '' -- other options ignored.
  else
    tex.sprint('\\def\\tmplegal{0}')
  end
  if string.find(s1, 'single,') then
    tex.sprint('\\def\\tmpsingle{1}') ; s1 = string.gsub(s1, 'single', '')
  end
  if string.find(s1, 'recto,') then
    tex.sprint('\\def\\tmprecto{1}') ; s1 = string.gsub(s1, 'recto', '')
  end
  if string.find(s1, 'guide=') then
    local g, n = string.gsub(s1, '.*guide=', '') ; g = string.gsub(g, ',.*', '')
    g = tonumber(g)
    if n == 1 and g and g == math.floor(g) and g >= 0 and g <= nvt.lines then
      tex.sprint('\\def\\tmpguide{' .. g .. '}') ; s1 = string.gsub(s1, 'guide=' .. g, '')
    end
  end
  if string.find(s1, 'style=') then
    local p, n = string.gsub(s1, '.*style=', '') ; p = string.gsub(p, ',.*', '')
    if n == 1 and (p == 'normal' or p == 'empty' or p == 'plain' or p == 'drop' or p == 'layout')
    then tex.sprint('\\def\\tmptps{' .. p .. '}') ; s1 = string.gsub(s1, 'style=' .. p, '')
    end
  end
  s1 = string.gsub(s1, ',', '')
  if s1 == '' then
    tex.sprint('\\def\\tmpreturn{1}')
  else
texio.write_nl('SSSSSSSSSSSSSSS=' .. s1 .. '<\n')
    tex.sprint('\\def\\tmpreturn{0}') ; nvt.good = false
  end
end
--


-- Attribution: Code by user "topskip". Simpler than full-scale code from other packages.
-- Prevents line wrap ending on single letter. You can still manually break using \\.
-- This is mandatory in some languages, desirable in others (such as English).
nvt.prevent_single_letter = function(head)
  while head do
    if head.id == GLYPH and unicode.utf8.match(unicode.utf8.char(head.char),'%a') then
      if head.prev.id == GLUE and head.next.id == GLUE then
        local p = node.new('penalty')
        p.penalty = 10000
        node.insert_after(head,head,p)
      end
    end
    head = head.next
  end
  return true
end
luatexbase.add_to_callback("pre_linebreak_filter",nvt.prevent_single_letter,"active~")
--


-- These functions are used for inspection and re-encoding metadata:
-- Attribution: Much of this code is derived from code by Oberdiek et. al., part of LaTeX:
function nvt.mdfivexmp (s)
  s = nvt.utf8_to_byte(s)
  local h = nvt.escapehex(md5.sum(s))
  local m0108 = string.sub(h,1,8)
  local m0912 = string.sub(h,9,12)
  local m1416 = string.sub(h,14,16)
  local m1821 = string.sub(h,18,21)
  local m2332 = string.sub(h,23,32)
  tex.sprint('uuid:' .. m0108 .. '-' .. m0912 .. '-4' .. m1416 .. '-8' .. m1821 .. '-' .. m2332)
end
--
function nvt.mdfiveinfo (s)
  s = nvt.utf8_to_byte(s)
  local H = nvt.escapeHEX(md5.sum(s))
  tex.sprint('<' .. H .. '>')
end
--
function nvt.utf8_to_byte (s)
  local i = 0 ; local n = string.len(s) ; local t = {}
  while i < n do
    i = i+1
    local a = string.byte(s,i)
    if a < 128 then
      table.insert(t,string.char(a))
    else
      if a >= 192 and i < n then
        i = i+1
        local b = string.byte(s,i)
        if b < 128 or b >= 192 then
          i = i-1
        elseif a == 194 then
        table.insert(t,string.char(b))
        elseif a == 195 then
          table.insert(t,string.char(b+64))
        end
      end
    end
  end
  return table.concat(t)
end
--
function nvt.escapehex (s)
  local e = string.gsub(s,'.',function(ch) return string.format("%02x",string.byte(ch)) end)
  return e
end
--
function nvt.escapeHEX (s)
  local e = string.gsub(s,".",function (ch) return string.format("%02X",string.byte(ch)) end)
  return e
end
--


-- Convert metadata to XML-compliant string, for XMP:
-- Need to use Entities.
function nvt.xmpify (s)
  local ls = utf8.len(s) ; local len = tonumber(ls)
  local c = '' ; local ci = 0 ; local cn = 0 ; local x = '' ; local i = 1
  while i <= len do
    c = unicode.utf8.sub(s,i,i) -- -----
    if c ~= '\\' then x = x .. c end
    i = i + 1
  end
  tex.sprint(x)
--  if x ~= '' then
--    tex.sprint('\\def\\tmps{\\detokenize{' .. x .. '}}')
--  else
--    tex.sprint('\\def\\tmps{}')
--  end
end
--


-- Convert metadata to octal codes, for Info dictionary:
function nvt.octify (s)
  local ls = utf8.len(s) ; local len = tonumber(ls)
  local c = '' ; local ci = 0 ; local cn = 0 ; local oct = '' ; local i = 1
  while i <= len do
    c = unicode.utf8.sub(s,i,i) -- -----
    if c ~= '\\' then
      cp = utf8.codepoint(c) --
      cpn = tonumber(cp)
      cn = string.format('%o',cpn)
      oct = oct .. '\\' .. cn
    end
    i = i+1
  end
  if oct ~= '' then
    tex.sprint('\\def\\tmps{\\detokenize{' .. oct .. '}}')
  else
    tex.sprint('\\def\\tmps{}')
  end
end
--


-- Catch LaTeX errors and warnings that may or may not use \GenericError or \GenericWarning code:
function nvt.flagbad()
  nvt.good = false
  local les = status.lasterrorstring or ''
  local lec = status.lasterrorcontext or ''
  if string.find(les, 'Paragraph ended before') then
    texio.write_nl('\nThis error is usually caused by one of these problems:')
    texio.write_nl('1. Unmatched braces. An ending brace is missing, or in the wrong place.')
    texio.write_nl('   Solution: Count the braces, and be sure that they match.')
    texio.write_nl('2. Some macros cannot continue from one paragraph to another.')
    texio.write_nl('   Example: "from \\textit{here\\par to} there" will fail.')
    texio.write_nl('   If the message mentions \\text@command, this is the most likely problem.') 
    texio.write_nl('   Solution: Break the command at paragraph boundaries:')
    texio.write_nl('   "from \\textit{here}\\par\\textit{to} there" succeeds.')
    texio.write_nl('3. Unescaped percent symbol was interpreted as comment.')
    texio.write_nl('   Example: 30% fails. But 30\\% succeeds.')
    texio.write_nl('Best response: x<return> to exit now, fix the problem, then try again.')
    texio.write_nl('  If you continue, this error will likely cause other errors.\n')
  end
  if les ~= '' and les ~= 'Emergency stop' then texio.write_nl(lec .. '\n') end
  nvt.luaerr = 0
end
luatexbase.add_to_callback('show_error_hook',nvt.flagbad,'catch_errors')
luatexbase.add_to_callback('show_lua_error_hook',
  function() nvt.good = false ; nvt.luaerr = 1 ; local lles = status.lastluaerrorstring or ''
    texio.write_nl(lles .. '\n') end,
  'catch_luaerrors')
--


-- Flag overfull and underfull boxes:
function nvt.overunderfull (incident,detail,head,first,last)
  if incident == 'overfull' then
    nvt.good = false ; nvt.overfull = nvt.overfull + 1 
    detail = tonumber(detail) or 0 ; detail = detail/(65536*nvt.em)
    texio.write_nl('Overfull \\hbox (badness 10000) in paragraph at lines '
      .. first .. '-' .. '-' .. last)
    texio.write_nl('  ^ Problem: Overfull ' .. string.format("%.2f",detail) .. 'em, '
      .. 'input line ' .. first .. '-' .. last .. ', PDFpage ' .. tex.getcount('c@page') .. '.\n')
    -- Hat tip to David Carlisle and MarcelKrüger, tex.stackexchange.com q.757822:
    local newn = node.new'rule' ; newn.width = 600000 ; return newn
  end
  if incident == 'underfull' then
    nvt.underfull = nvt.underfull + 1 ; local stretch = ''
    if head.glue_set > 0 then
      stretch = string.format('%.1f%s',head.glue_set/1.5,'') .. 'x max, '
    end
    texio.write_nl('Underfull \\hbox (badness 10000) in paragraph at lines '
      .. first .. '-' .. '-' .. last)
    texio.write_nl('  ^ Alert: Excessive stretch, ' .. stretch .. 'input line '
      .. first .. '-' .. last .. ', PDFpage ' .. tex.getcount('c@page') .. '.\n')
  end
end
luatexbase.add_to_callback('hpack_quality',nvt.overunderfull,'overunder_full')
--


-- Get Character Accents:
-- The TU encoding defines many macros used for accented characers, such as \'e for eacute.
-- Some of the accented characters are not available in Novelette. Without hacking TU,
-- the resulting error message would be hard to understand. This hacks TU so that when a macro
-- calls for an accented character not in Novelette, the error is clearer. 
function nvt.getcharaccent (a,c) -- accent, base character
  local n = 0 ; local d = 'unknown diacritical' ; local fd, fc, e
  local lc = string.len(c) ; local em2 = ''
  if a == '"0300' then d = 'grave' end
  if a == '"0301' then d = 'acute' end
  if a == '"0302' then d = 'circumflex' end
  if a == '"0303' then d = 'tilde' end
  if a == '"0304' then d = 'macron' end
  if a == '"0306' then d = 'breve' end
  if a == '"0307' then d = 'dot above' end
  if a == '"0308' then d = 'dieresis' end
  if a == '"030A' then d = 'ring above' end
  if a == '"030B' then d = 'double acute' end
  if a == '"030C' then d = 'caron' end
  if a == '"0323' then d = 'dot below' end
  if a == '"0326' then d = 'comma below' end
  if a == '"0327' then d = 'cedilla' end
  if a == '"0328' then d = 'ogonek' end
  if lc == 0 then
    if d == 'tilde' then tex.sprint('\\asciitilde{}') ; n = 2 end
    if d == 'circumflex' then tex.sprint('\\asciicircumflex{}') ; n = 2 end
    if n == 0 then
      em2 = 'Only diacriticals \\~{} and \\^{} allow empty braces.'
      n = 3 ; nvt.good = false
    end
  elseif lc == 1 then
    fd = string.find('grave',d) or string.find('acute',d)
    fd = fd or string.find('circumflex',d) or string.find('dieresis',d)
    fc = string.find('AEIOUWYaeiouwy',c)
    if fd and fc then n = 1 end
    if (d == 'ring above') and string.find('Aa',c) then n = 1 end
    if (d == 'cedilla') and string.find('Cc',c) then n = 1 end
    if (d == 'tilde') and string.find('ANOano',c) then n = 1 end
    if (d == 'macron') and string.find('AEIOUaeiou',c) then n = 1 end
    if (d == 'acute') and string.find('Jj',c) then
      e = 'Unavailable as single character: J or j with acute.\n'
      e = e .. '\\space\\space For IJ or ij with both acute:'
      e = e .. '\\space \\string\\IJacute\\space or \\string\\ijacute.'
      em2 = e ; n = 4 ; nvt.good = false
    end
  end
  if n == 0 then
    tex.sprint('\\gdef\\tmpnum{0}' .. c) ; nvt.good = false
    em2 = 'No ' .. c .. ' with ' .. d .. ' diacritical.'
  else
    tex.sprint('\\gdef\\tmpnum{1}')
  end
  tex.sprint('\\def\\emtwo{' .. em2 .. '}')
end
--


-- Parse \title, \author, \subtitle, \version:
-- Parentheses () have special meaning in PDF, similar to braces {} in LaTeX. If your metadata
-- contains unmatched parentheses, big problem. These enforce matched parentheses, if any used.
function nvt.parsetitle(s)
  if nvt.didtitle == true then
    tex.sprint('\\def\\tmpreturn{-1}') ; nvt.good = false
  else
    nvt.didtitle = true  ----- use unicode.utf8.sub(x,y,z)
    local sp = string.gsub(s, '[^%(%)]', '') ; sp = string.gsub(sp, '%(%)', '')
    if string.len(sp) > 0 then
      tex.sprint('\\def\\tmpreturn{0}') ; nvt.good = false
    else
      s = string.gsub(s, '^ ', '') ; s = string.gsub(s, ' $', '')
      s = string.gsub(s, '\\', ' ') ; s = string.gsub(s, '  ', ' ')
      nvt.title = s ; tex.sprint('\\def\\tmptitle{' .. s .. '}')
    end
  end
end
--
function nvt.parsesubtitle(s)
  if nvt.didsubtitle == true then
    tex.sprint('\\def\\tmpreturn{-1}') ; nvt.good = false
  else
    nvt.didsubtitle = true  ----- use unicode.utf8.sub(x,y,z)
    local sp = string.gsub(s, '[^%(%)]', '') ; sp = string.gsub(sp, '%(%)', '')
    if string.len(sp) > 0 then
      tex.sprint('\\def\\tmpreturn{0}') ; nvt.good = false
    else
      s = string.gsub(s, '^ ', '') ; s = string.gsub(s, ' $', '')
      s = string.gsub(s, '\\', ' ') ; s = string.gsub(s, '  ', ' ')
      nvt.subtitle = s ; tex.sprint('\\def\\tmpsubtitle{' .. s .. '}')
    end
  end
end
--
function nvt.parseauthor(s)
  if nvt.didauthor == true then
    tex.sprint('\\def\\tmpreturn{-1}') ; nvt.good = false
  else
    nvt.didauthor = true  ----- use unicode.utf8.sub(x,y,z)
    local sp = string.gsub(s, '[^%(%)]', '') ; sp = string.gsub(sp, '%(%)', '')
    if string.len(sp) > 0 then
      tex.sprint('\\def\\tmpreturn{0}') ; nvt.good = false
    else
      s = string.gsub(s, '^ ', '') ; s = string.gsub(s, ' $', '')
      s = string.gsub(s, '\\', ' ') ; s = string.gsub(s, '  ', ' ')
      nvt.author = s ; tex.sprint('\\def\\tmpauthor{' .. s .. '}')
    end
  end
end
--
function nvt.parseversion(s)
  if nvt.didversion == true then
    tex.sprint('\\def\\tmpreturn{-1}') -- but still good
  else
    nvt.didversion = true  ----- use unicode.utf8.sub(x,y,z)
    local sp = string.gsub(s, '[^%(%)]', '') ; sp = string.gsub(sp, '%(%)', '')
    if string.len(sp) > 0 then
      tex.sprint('\\def\\tmpreturn{0}') ; nvt.good = false
    else
      s = string.gsub(s, '^ ', '') ; s = string.gsub(s, ' $', '')
      s = string.gsub(s, '\\', ' ') ; s = string.gsub(s, '  ', ' ')
      nvt.version = s ; tex.sprint('\\def\\tmpversion{' .. s .. '}')
    end
  end
end
--


-- Parse \docdate:
-- The docdate format is yyyy/mm/dd but the range of numbers is not checked. This changes
-- the string from your easy-to-read setting, to the string format used within PDF.
function nvt.parsedocdate (s)
  if nvt.diddocdate == true then
    tex.sprint('\\def\\tmpreturn{-1}') -- but still good
  else
    nvt.diddocdate = true
    s = string.gsub(s,' ','')
    if s == '' then
      tex.sprint('\\def\\tmpreturn{1}\\def\\tmpdocdate{}')
    else
      local z = string.gsub(s, '^%d%d%d%d/%d%d/%d%d$','')
      if z == '' then
        s = string.gsub(s,'/','')
        nvt.docdate = 'D:' .. str .. "000001Z"
        tex.sprint('\\def\\tmpreturn{1}\\def\\tmpdocdate{' .. nvt.docdate .. '}')
      else
        nvt.good = false
        nvt.docdate = nvt.now
        tex.sprint('\\def\\tmpdocdate{}')
        tex.sprint('\\def\\tmpreturn{0}')
      end
    end
  end
end
--


-- Parse \trimsize setting:
-- Lua calculates and records in Tex pt, converted to Postscript (bp) by LaTEX.
function nvt.parsetrimsize (s)
  if nvt.didtrimsize == true then
    tex.sprint('\\def\\tmpreturn{-1}') ; nvt.good = false
  else
    nvt.didtrimsize = true
    nvt.trimtext = s
    s = s .. ',' ; s = string.gsub(s, ' ' ,'')
    local n, m, w, h, wd, ht ; local ok = true
    if s == '' then s = 'width=5.5in,height=8.5in,' end
    w, n = string.gsub(s, '.*width=', '') ; w = string.gsub(w, ',.*', '')
    h, m = string.gsub(s, '.*height=', '') ; h = string.gsub(h, ',.*', '')
    if n ~= 1 or m ~= 1 then ok = false end
    if ok == true then
      wd, n = string.gsub(w, 'in$', '') ; ht, m = string.gsub(h, 'in$', '')
      if n == 1 and m == 1 then
        wd = tonumber(wd) ; ht = tonumber(ht)
        if not wd or not ht then
          ok = false
        else
          if wd < 5 or wd > 6 or ht < 7.7 or ht > 9.3 or wd > (ht - 2) then
            ok = false
          else
            tex.sprint('\\def\\tmpmetric{0}')
            s = string.gsub(s, 'width=' .. wd .. 'in', '')
            nvt.trimwidth = nvt.inch * wd ; nvt.trimheight = nvt.inch * ht ;
            tex.sprint('\\def\\tmptw{' .. nvt.trimwidth .. '}')
            s = string.gsub(s, 'height=' .. ht .. 'in', '')
            tex.sprint('\\def\\tmpth{' .. nvt.trimheight .. '}')
          end
        end
      else
        wd, n = string.gsub(w, 'mm$', '') ; ht, m = string.gsub(h, 'mm$', '')
        if n == 1 and m == 1 then
          wd = tonumber(wd) ; ht = tonumber(ht) ; nvt.metric = 1
          if not wd or not ht then
            ok = false
          else
            if wd < 126 or wd > 157 or ht < 197 or ht > 235 or wd > (ht - 68) then
              ok = false
            else
            tex.sprint('\\def\\tmpmetric{1}')
            s = string.gsub(s, 'width=' .. wd .. 'mm', '')
            nvt.trimwidth = nvt.mm * wd ; nvt.trimheight = nvt.mm * ht ;
            tex.sprint('\\def\\tmptw{' .. nvt.trimwidth .. '}')
            s = string.gsub(s, 'height=' .. ht .. 'mm', '')
            tex.sprint('\\def\\tmpth{' .. nvt.trimheight .. '}')
            end
          end
        else
          ok = false
        end
      end
    end
    s = string.gsub(s, ',', '')
    if s ~= '' or ok == false then
      nvt.good = false ; tex.sprint('\\def\\tmpreturn{0}')
    else
      tex.sprint('\\def\\tmpreturn{1}')
    end
  end
end
--


-- Parse \layout setting:
function nvt.parselayout (s)
  if nvt.didlayout == true then
    tex.sprint('\\def\\tmpreturn{-1}') ; nvt.good = false
  else
    nvt.didlayout = true
    s = s .. ',' ; s = string.gsub(s, ' ' ,'') ; s = string.gsub(s, 'lines=', 'line=')
    local p, l, n, g, c ; local ok = true
    tex.sprint('\\begingroup\\makeatletter')
    if string.find(s, 'pagestyle=') then
      p, n = string.gsub(s, '.*pagestyle=', '') ; p = string.gsub(p, ',.*', '')
      if n == 1 and string.find(':none:plain:center:margin:marcen:split:', ':' .. p .. ':') then
        tex.sprint('\\gdef\\nvt@pagestyle{' .. p .. '}') ; nvt.pagestyle = p
        s = string.gsub(s, 'pagestyle=' .. p, '')
        if p == 'none' then nvt.header = false ; nvt.footer = false
        elseif p == 'plain' then nvt.header = false ; nvt.footer = true
        elseif p == 'split' then nvt.header = true ; nvt.footer = true
        else nvt.header = true ; nvt.footer = false
        end
      end
    end
    if string.find(s, 'line=') then
      l, n = string.gsub(s, '.*line=', '') ; l = string.gsub(l, ',.*', '') ; l = tonumber(l)
      if n == 1 and l and l >= 26 and l <= 35 and math.floor(l) == l then
        nvt.lines = l ; tex.sprint('\\gdef\\nvt@lines{' .. l .. '}')
        s = string.gsub(s, 'line=' .. l, '')
      end
    end
    if string.find(s, 'glue=') then
      g, n = string.gsub(s, '.*glue=', '') ; g = string.gsub(g, ',.*', '')
      if n == 1 then
        if g == 'wide' or g == 'normal' then s = string.gsub(s, 'glue=' .. g, '') end
        if g == 'wide' then nvt.moreglue = true ; tex.sprint('\\global\\nvt@moregluetrue') end
      end
    end
    if string.find(s, 'cpl=') then
      c, n = string.gsub(s, '.*cpl=', '') ; c = string.gsub(c, ',.*', '')
      if n == 1 then
        c = tonumber(c)
        if c and c >= 62 and c <= 70 then
          nvt.charperline = c ; tex.sprint('\\gdef\\nvt@charperline{' .. c .. '}')
          s = string.gsub(s, 'cpl=' .. c, '')
        end
      end
    end
    s = string.gsub(s, ',', '')
    tex.sprint('\\endgroup')
  end
  if s ~= '' or ok == false then
    nvt.good = false ; tex.sprint('\\def\\tmpreturn{0}')
  else
    tex.sprint('\\def\\tmpreturn{1}')
  end
end
--


-- Parse pdfx setting:
function nvt.parsepdfx (s)
  if nvt.didpdfx == true then
    tex.sprint('\\def\\tmpreturn{-1}') ; nvt.good = false
  else
    nvt.didpdfx = true
    s = string.gsub(s, ' ', '') ; s = string.gsub(s, ',' ,'')
    tex.sprint('\\begingroup\\makeatletter')
    if nvt.lang == 'usenglishmax' or nvt.lang == 'en' then
      nvt.oi = 'swop'
    else
      nvt.oi = 'fogra'
    end
    if string.find(s, 'swop') then nvt.oi = 'swop' ; s = string.gsub(s, 'swop', '')
    elseif string.find(s, 'fogra') then nvt.oi = 'fogra' ; s = string.gsub(s, 'fogra' ,'')
    elseif string.find(s, 'off') then
      nvt.pdfx = false ; nvt.oi = '' ; s = string.gsub(s, 'off', '')
    end
    if s == '' then tex.sprint('\\gdef\\nvt@oi{' .. nvt.oi .. '}') end
    tex.sprint('\\endgroup')
  end
  if s == '' then
    tex.sprint('\\def\\tmpreturn{1}')
  else
    tex.sprint('\\def\\tmpreturn{0}') ; nvt.pdfx = false ; nvt.good = false
  end
end
--


-- Parse \lang setting:
nvt.parselang = function (s)
  if nvt.didlang == true then
    tex.sprint('\\def\\tmreturn{-1}') ; nvt.good = false
  else
    nvt.didlang = true
    s = string.gsub(s, ' ', '') ; s = string.gsub(s, '%-', '')
    local ok = false ; local k = 1
    s = string.lower(s)
    if string.find(s, '^enuk') or string.find('engb') then nvt.lang = 'british' ; ok = true end
    if s == 'enus' then nvt.lang = 'usenglishmax' ; ok = true end
    if string.find(s, '^de') then nvt.lang = 'ngerman' ; ok = true end
    if s == 'dech' then nvt.lang = 'swissgerman' ; ok = true end
    if string.find(s, '^nn') then nvt.lang = 'nynorsk' ; ok = true end
    if string.find(s, '^no') or string.find(s, '^nb') then nvt.lang = bokmal ; ok = true end
    if string.find(s, '^fr') then nvt.lang = 'french' ; ok = true end
    if string.find(s, '^pt') then nvt.lang = 'portuguese' ; ok = true end
    if string.find(s, '^ca') then nvt.lang = 'catalan' ; ok = true end
    if string.find(s, '^es') then nvt.lang = 'spanish' ; ok = true end
    if string.find(s, '^it') then nvt.lang = 'italian' ; ok = true end
    if string.find(s, '^nl') then nvt.lang = 'dutch' ; ok = true end
    if string.find(s, '^sv') then nvt.lang = 'swedish' ; ok = true end
    if string.find(s, '^da') then nvt.lang = 'danish' ; ok = true end --
    if string.find(s, '^fi') then nvt.lang = 'finnish' ; ok = true end --
    if string.find(s, '^eu') then nvt.lang = 'basque' ; ok = true end --
    if string.find(s, '^ga') then nvt.lang = 'irish' ; ok = true end -- gaelic
    if string.find(s, '^cy') then nvt.lang = 'welsh' ; ok = true end --
    if string.find(s, '^is') then nvt.lang = 'icelandic' ; ok = true end --
    if string.find(s, '^gd') then nvt.lang = 'scottish' ; ok = true end -- gaelic
    if string.find(s, '^la') then nvt.lang = 'latin' ; ok = true end --
    if s == 'en' then
      nvt.lang = 'english' ; ok = true ; k = 3
    end
    if s == 'xx' then
      nvt.lang = 'english' ; ok = true ; k = 2
      tex.sprint('\\hyphenpenalty 10000\\relax\\exhyphenpenalty 10000\\relax')
      nvt.nohyphens = true
    end
  end
  if ok == true then
    tex.sprint('\\def\\tmplang{' .. nvt.lang .. '}\\def\\tmpreturn{' .. k .. '}')
  else
    nvt.lang = 'english' ; nvt.good = false ; tex.sprint('\\def\\tmpreturn{0}')
  end
end
--


-- Parse \enable setting(s), which may be used more than once, with cumulative effect:
function nvt.parseenable (s)
  local conflict = false ; local g = 0
  s = s .. ',' ; s = string.gsub(s,' ','')
  if string.find(s,'britq,') then
    tex.sprint('\\def\\tmpbritq{1}') ; s=string.gsub(s,'britq','')
  end
  if string.find(s,'xmp,') then
    tex.sprint('\\def\\tmpxmp{1}') ; s=string.gsub(s,'xmp','')
  end
  if string.find(s,'guide=') then
    g = string.gsub(s, '.*guide=', '') ; g = string.gsub(g, ',.*', '')
    if g ~= '' and g ~= 'last' then
      g = tonumber(g)
      if g and g >= 1 and g == math.floor(g) then
        tex.sprint('\\def\\tmphasguide{1}') ; tex.sprint('\\def\\tmpguideline{' .. g .. '}')
        nvt.guide = g ; s = string.gsub(s, 'guide=' .. g, '')
      end
    end
    if g == 'last' then
      tex.sprint('\\def\\tmphasguide{1}') ; tex.sprint('\\def\\tmpguideline{0}')
      s = string.gsub(s, 'guide=last', '')
    end
  end
  s=string.gsub(s,',','')
  if (s ~= '') or (conflict == true) then
    nvt.good = false ; tex.sprint('\\def\\tmpreturn{0}')
  else
    tex.sprint('\\def\\tmpreturn{1}')
  end
end
--


-- Parse disable setting(s), which may be used more than once, for cumulative effect:
function nvt.parsedisable (s)
  s = s .. ',' ; s = string.gsub(s, ' ', '')
  if string.find(s, 'blankend,') then
    tex.sprint('\\def\\tmpnoblankend{1}') ; s = string.gsub(s, 'blankend', '')
  end
  if string.find(s,'renumber,') then
    tex.sprint('\\def\\tmpnorenumber{1}') ; s = string.gsub(s, 'renumber', '')
  end
  if string.find(s, 'pageflip,') then
    nvt.nopageflip = true ; tex.sprint('\\def\\tmpnopageflip{1}')
    s = string.gsub(s, 'pageflip', '')
  end
  if string.find(s,'autodeco,') then
    tex.sprint('\\def\\tmpnoautodeco{1}') ; s = string.gsub(s, 'autodeco', '')
  end
  if string.find(s,'metasub,') then
    tex.sprint('\\def\\tmpnometasub{1}') ; s=string.gsub(s,'metasub','')
  end
  s = string.gsub(s, 'guides,', 'guide,')
  if string.find(s,'guide,') then
    tex.sprint('\\def\\tmpnoguide{1}') ; s=string.gsub(s,'guide','')
  end
  s=string.gsub(s, ',', '')
  if s ~= '' then
    nvt.good = false ; tex.sprint('\\def\\tmpreturn{0}')
  else
    tex.sprint('\\def\\tmpreturn{1}')
  end
end
--


-- Parse \examine setting: ---- nvt.didexamine ?
nvt.parseexamine = function (s)
  s = string.gsub(s, ' ', '') ; local n = 0
  if string.find(s, '1,') then
     tex.sprint('\\def\\tmpex{1}') ; s = string.gsub(s, '1', '') ; n = n + 1
  end
  if string.find(s, '0,') then s = string.gsub(s, '0', '') ; n = n + 1 end
  if s ~= '' or n > 1 then tex.sprint('\\def\\tmpreturn{0}') end
end
--


-- Main font size and side margins are not settings. They are calculated from other settings:
function nvt.calculatehorizontal ()
  if nvt.metric == 1 then
    nvt.minmargin = 13*nvt.mm ; if nvt.trimwidth < 139.7*nvt.mm then nvt.minmargin = 10*nvt.mm end
    nvt.glue = 3.2*nvt.mm ; if nvt.moreglue == true then nvt.glue = 6.4*nvt.mm end
  else
    nvt.minmargin = 0.5*nvt.inch
    if nvt.trimwidth < 5.5*nvt.inch then nvt.minmargin = 0.375*nvt.inch end
    nvt.glue = 0.125*nvt.inch ; if nvt.moreglue == true then nvt.glue = 0.25*nvt.inch end
  end
  local maxtextwidth = nvt.trimwidth - (2*nvt.minmargin) - nvt.glue
  nvt.textwidth = maxtextwidth
  nvt.em = nvt.textwidth / (nvt.charperline*0.386) -- Try em based on textwidth and char/line.
  if nvt.em > 12.05 then -- If necessary, limit em, and adjust textwidth.
    nvt.em = 12.05 ; nvt.textwidth = nvt.em*nvt.charperline*0.386
  end
  if nvt.mode == 'draft' and nvt.nopageflip == true then -- Split glue strip, for easier editing.
    nvt.evensidemargin = 0.5*(nvt.trimwidth-nvt.textwidth)
    nvt.oddsidemargin = 0.5*(nvt.trimwidth-nvt.textwidth)
  else -- Glue strip alternates, as in print.
    nvt.evensidemargin = 0.5*(nvt.trimwidth-nvt.textwidth-nvt.glue)
    nvt.oddsidemargin = 0.5*(nvt.trimwidth-nvt.textwidth+nvt.glue)
  end
end
--


-- Normal baselineskip and top/bottom margins are not settings. They are calculated:
function nvt.calculatevertical ()
  local maxprintheight = nvt.trimheight - (2 * nvt.minmargin) -----
  local minbaselineskip = 1.2 * nvt.em
  local linetotal = nvt.lines + .3
  if nvt.header == true then linetotal = linetotal + 1.7 end -----
  if nvt.footer == true then linetotal = linetotal + 2 end -----
  nvt.bls = maxprintheight/linetotal
  if nvt.bls < minbaselineskip then -- Adjust em, textwidth, and bls.
    local tweak = nvt.bls/minbaselineskip
    nvt.em = tweak * nvt.em
    nvt.textwidth = tweak * nvt.textwidth
    nvt.bls = 1.2 * nvt.em
    nvt.evensidemargin = 0.5 * (nvt.trimwidth - nvt.textwidth - nvt.glue)
    nvt.oddsidemargin = 0.5 * (nvt.trimwidth - nvt.textwidth + nvt.glue)
  end
  if (nvt.bls/nvt.em) > 1.5 then -- Adjust bls and topmargin.
    local excess = 0.5 *(linetotal * (nvt.bls - 1.5*nvt.em))
    nvt.bls = 1.5*nvt.em ; nvt.topmargin = nvt.minmargin + excess
  else
    nvt.topmargin = nvt.minmargin
  end
  nvt.linegap = 0.3*nvt.bls - 0.23*nvt.em
  tex.sprint('\\def\\tmplinegap{' .. nvt.linegap .. 'pt}')
  tex.sprint('\\def\\tmpfontem{' .. nvt.em .. 'pt}')
  tex.sprint('\\def\\tmpbls{' .. nvt.bls .. 'pt}')
  tex.sprint('\\def\\tmptextwd{' .. nvt.textwidth .. 'pt}')
  tex.sprint('\\def\\tmpesm{' .. nvt.evensidemargin .. 'pt}')
  tex.sprint('\\def\\tmposm{' .. nvt.oddsidemargin .. 'pt}')
  tex.sprint('\\def\\tmpmm{' .. nvt.minmargin .. 'pt}')
  tex.sprint('\\def\\tmpglue{' .. nvt.glue .. 'pt}')
--  if nvt.header == true then
--    nvt.topmargin = nvt.minmargin
--  else
--    nvt.topmargin = nvt.minmargin - 0.3*nvt.bls
--  end
  tex.sprint('\\def\\tmptopm{' .. nvt.topmargin .. 'pt}')
end
--


-- Finalize, with wrapup message to Terminal:
nvt.finalize = function ()
  if nvt.good == false then
    tex.sprint('\\def\\tmpmode{bad}') ; nvt.mode = 'draft'
    luatexbase.add_to_callback('wrapup_run', function ()
      texio.write_nl('\n! Fix problems: errors, warnings, or overfull boxes.\n\n')
    end, 'nvt_wrapup')
  else
    tex.sprint('\\def\\tmpmode{' .. nvt.mode .. '}')
    luatexbase.add_to_callback('wrapup_run', function ()
      texio.write('\n\n')
      texio.write_nl('********************************** '
        .. 'SUMMARY **********************************')
      texio.write_nl('Compiled at: ' .. nvt.now)
      texio.write_nl('Title: ' .. nvt.title)
      if nvt.subtitle ~= '' then texio.write_nl('Subtitle: ' .. nvt.subtitle) end
      texio.write_nl('Author: ' .. nvt.author)
      if nvt.docdate ~= '' then texio.write_nl('Docdate: ' .. nvt.docdate) end
      if nvt.version ~= '' then texio.write_nl('Version: ' .. nvt.version) end
      if nvt.countnext ~= 0 and nvt.mode ~= 'bad' then nvt.mode = 'draft' end
      local ng
      if nvt.mode == nvt.startmode then
        texio.write_nl('Mode: ' .. nvt.mode)
      else
        if nvt.countnext ~= 0 then
          ng = ', but denied due to ' .. nvt.countnext .. ' instances of \\next.'
        else
          ng = ', but denied due to error/warning/overfull.'
        end
        texio.write_nl('Mode: draft. Requested ' .. nvt.startmode .. ng)
      end
      texio.write_nl('Trim Size: ' .. nvt.trimtext)
      local twin, emin, blin
      local l = 'lines=' .. nvt.lines .. ',pagestyle=' .. nvt.pagestyle
      if nvt.moreglue == true then l = l .. ',glue=wide,' else l = l .. ',glue=normal,' end
      l = l .. 'cpl=' .. nvt.charperline
      texio.write_nl('Layout: ' .. l)
      texio.write_nl('Font: em=' .. string.format("%.2f", nvt.em) .. 'pt, baselineskip='
        .. string.format("%.2f", nvt.bls) .. 'pt, ratio baselineskip/em='
        .. string.format("%.2f", nvt.bls/nvt.em))
      if nvt.em < 11.04 then
        texio.write_nl('Alert: Small font size. Try bigger trimsize, or fewer lines.')
      elseif nvt.em <= 11.6 and nvt.pagestyle == 'split' then
        texio.write_nl('Alert: Crowded layout. Will look better if pagestyle is not split.')
      end
      twin = nvt.textwidth/nvt.inch ; emin = nvt.em/nvt.inch ; blin = nvt.bls/nvt.inch
      texio.write_nl('Images: max W ' .. string.format("%.4f", twin) .. 'in, '
        .. 'max H ' .. string.format("%.4f", emin) .. 'in first line, '
        .. string.format("%.4f", blin) .. 'in each added line.')
      local outm, outmt, glus, glusmt
      if nvt.metric == 1 then
        outm = nvt.evensidemargin/nvt.mm
        outmt = string.format("%.2f", outm) .. 'mm'
        glus = nvt.glue/nvt.mm
        glusmt = string.format("%.2f", glus) .. 'mm'
      else
        outm = nvt.evensidemargin/nvt.inch
        outmt = string.format("%.3f", outm) .. 'in'
        glus = nvt.glue/nvt.inch
        glusmt = string.format("%.3f", glus) .. 'in'
      end
      texio.write_nl('Margins: at least ' .. outmt .. ', plus ' .. glusmt .. ' spine glue strip.')
      if nvt.nohyphens == true then
        texio.write_nl('Hyphenation: disabled by \\lang{xx} choice.')
      else
        if nvt.lang == 'en' then
          texio.write_nl('Hyphenation: en (Default. For English, better to use en-US or en-UK)')
        else
          texio.write_nl('Hyphenation language: ' .. nvt.lang)
        end
      end
      if nvt.countnext ~= 0 then
        texio.write_nl('Alert: ' .. nvt.countnext .. ' instances of \\next. '
          .. 'Prevents preview and final modes.')
      end
      if nvt.examine == true then
        if nvt.pagelist == '' then
          texio.write_nl('Info: No typographic flaws found. Good!')
        else
          texio.write_nl('Alert: Found typographic flaws. See file ' .. tex.jobname .. '.typo.')
          texio.write_nl('  Whether or not to fix any flaws, is your decision.')
        end
      end
      if nvt.underfull > 0 then
        texio.write_nl('Alert: Found ' .. nvt.underfull .. ' line(s) with excessive stretch.')
        texio.write_nl('  Too much inter-word space. If not intentional, edit text there.')
      end
      if nvt.overfull > 0 then
        texio.write_nl('Problem: Found ' .. nvt.overfull .. ' overfull line(s).')
        texio.write_nl('  Novelette does not allow lines to extend into the margins.')
      end
      if nvt.qq > 0 then
        texio.write_nl('Problem: Found ' .. nvt.qq .. ' printable " straight double quotes.')
        texio.write_nl('  You must edit them to left and right curly, or use \\real{"}.')
      end
      if nvt.todo > 0 then
        texio.write_nl('Problem: Found ' .. nvt.todo .. ' TODO symbol(s).')
        texio.write_nl('  You must replace them with text (or remove them, if no text).')
      end
      if nvt.misschars > 0 then
        texio.write_nl('Problem: Missing character(s). List by Unicode:')
        texio.write_nl(' ' .. nvt.misslist)
      end
      if nvt.good == false then
        texio.write_nl('EEEEEEK !!! One or more errors, warnings, or problems.')
      end
      if nvt.thisdoc ~= '' then
        texio.write_nl('Note: When compiling only subdocs, mode is never preview or final.')
      end
      if nvt.good == false then texio.write_nl('Note: Forced draft mode, due to problems.') end
      texio.write_nl('******************************** '
        .. 'END SUMMARY ********************************')
      texio.write('\n\n')
    end, 'nvt_wrapup')
  end
end
--



-- End of file 'novelette-luasupport.lua'.
