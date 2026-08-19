-- This is file 'novelette-luasupport.lua', part of Novelette document class.
-- For Copyright and License, see accompanying file 'novelette.cls'.
-- File version: 2026-04-25.
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

-- Conversion of some useful length values to TeX pt:
nvt.inch=72.27
nvt.mm=2.8452755876
--

-- Variables. These are the defaults. Quotes mean that the variable is a string, even if it looks
-- like a number. Without quotes, the variable is a number or a boolean.
nvt.subdocs = {'placeholder'} -- Holds path/filename for \subdoc call, to prevent cyclic error.
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
local glyph = node.id('glyph')
local hlist = node.id('hlist')
local vlist = node.id('vlist')
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
  if string.find(opt, 'type=scene') then
     sc = 1 ; opt = string.gsub(opt, 'type=scene', '') ; label = 'sceneimage'
  end
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
  opt = string.gsub(opt, ' ', '') ; opt = opt .. ','
  a, n = string.gsub(opt, '.*align=', '') ; a = string.gsub(a, ',.*', '')
  if n > 1 then ok = false end
  if sc == 1 then
    tex.sprint('\\def\\tmpimgalign{-1}')
  elseif a == 'center' then
    tex.sprint('\\def\\tmpimgalign{0}') ; opt = string.gsub(opt, 'align=center', '')
  elseif a == 'left' then
    tex.sprint('\\def\\tmpimgalign{1}') ; opt = string.gsub(opt, 'align=left', '')
  elseif a == 'right' then
    tex.sprint('\\def\\tmpimgalign{2}') ; opt = string.gsub(opt, 'align=right', '')
  end
  t, n = string.gsub(opt, '.*tweak=', '') ; t = string.gsub(t, ',.*', '')
  if n > 1 then ok = false end
  if sc == 1 then
    tex.sprint('\\def\\tmptweak{-1}')
  elseif t == 'mid' then
    tex.sprint('\\def\\tmptweak{0}') ; opt = string.gsub(opt, 'tweak=mid','')
  elseif t == 'up' then
    tex.sprint('\\def\\tmptweak{1}') ; opt = string.gsub(opt, 'tweak=up','')
  elseif t == 'down' then
    tex.sprint('\\def\\tmptweak{2}') ; opt = string.gsub(opt, 'tweak=down','')
  end
  f, n = string.gsub(opt, '.*float=', '') ; f = string.gsub(f, ',.*','')
  if n > 1 then ok = false  end
  if sc == 1 or f == 'none' then
    tex.sprint('\\def\\tmpfloat{0}') ; opt = string.gsub(opt, 'float=none', '')
  elseif f == 'here' then
    tex.sprint('\\def\\tmpfloat{1}') ; opt = string.gsub(opt, 'float=here', '')
  elseif f == 'top' then
    tex.sprint('\\def\\tmpfloat{2}') ; opt = string.gsub(opt, 'float=top', '')
  elseif f == 'bottom' then
    tex.sprint('\\def\\tmpfloat{3}') ; opt = string.gsub(opt, 'float=bottom', '')
  end
  if sc == 1 then
    tex.sprint('\\def\\tmplines{1}')
  elseif f == 'page' then
    tex.sprint('\\def\\tmplines{' .. (nvt.lines - 6) .. '}')
  else
    l, n = string.gsub(opt, '.*lines=', '') ; l = string.gsub(l, ',.*', '')
    if n > 1 then ok = false end
    lx = l ; l = tonumber(l) -- Sometimes tonumber changes string format. Preserve original as lx.
    if l and l == math.floor(l) and l > 1 and l <= nvt.lines then
      tex.sprint('\\def\\tmplines{' .. lx .. '}') ; opt = string.gsub(opt, 'lines=' .. lx, '')
    else
      ok = false
    end
  end
  opt = string.gsub(opt, ',', '') ; if opt ~= '' then ok = false end
  if ok == true then
    tex.sprint('\\def\\tmpimgreturn{1}')
  else
    tex.sprint('\\def\\tmpimgreturn{0}') ; nvt.good = false
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
    local m = ''
    s = string.gsub(s, ' ', '')
    if s == 'draft' or s == '' then m = 'draft'
    elseif s == 'preview' then m = 'preview'
    elseif s == 'final' then m = 'final'
    elseif s == 'dev' then m = 'dev'
    elseif s == 'usl' then m = 'usl'
    end 
    if m ~= '' then
      nvt.mode = m ; nvt.startmode = m
      tex.sprint('\\def\\tmpmode{' .. m .. '}')
      tex.sprint('\\def\\tmpreturn{1}')
    else
      nvt.good = false ; tex.sprint('\\def\\tmpreturn{0}')
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


-- Parse \devcode setting:
nvt.parsedevcode = function (s)
  s = string.gsub(s, ' ', '')
  if string.find(s, '%.tex$') or string.find(s, '%.lua$') then
    tex.sprint('\\begingroup\\makeatletter\\gdef\\nvt@devcode{' .. s .. '}\\endgroup')
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
    if t.id == hlist or t.id == vlist then nvt.get_page_glyphs(t.list,n+1) end
    if t.id == glyph then
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
  if string.find(s, 'deco=') then -- only head chooses deco
    d, n = string.gsub(s, '.*deco=', '') ; d = string.gsub(d, ',.*', '')
    if n == 1 then
      if d == 'none' then s = string.gsub(s, 'deco=none', '') ; tex.sprint('\\def\\tmpdn{0}')
      elseif d == 'bar' then s = string.gsub(s, 'deco=bar', '') ; tex.sprint('\\def\\tmpdn{1}')
      elseif d == 'bullet' then
        s = string.gsub(s, 'deco=bullet', '') ; tex.sprint('\\def\\tmpdn{2}')
      elseif d == 'square' then
        s = string.gsub(s, 'deco=square', '') ; tex.sprint('\\def\\tmpdn{3}')
      elseif d == 'lozenge' then
        s = string.gsub(s, 'deco=lozenge', '') ; tex.sprint('\\def\\tmpdn{4}')
      elseif d == 'dash' then
        s = string.gsub(s, 'deco=dash', '') ; tex.sprint('\\def\\tmpdn{5}')
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
    if n == 1 then
      if f == 'main' then
        s = string.gsub(s, 'font=main', '') ; tex.sprint{'\\def\\tmpfn{0}\\def\\tmpsp{.21}'}
      end
      if f == 'dark' then
        s = string.gsub(s, 'font=dark', '') ; tex.sprint{'\\def\\tmpfn{1}\\def\\tmpsp{.21}'}
      end
      if f == 'thick' then
        s = string.gsub(s, 'font=thick', '') ; tex.sprint{'\\def\\tmpfn{2}\\def\\tmpsp{.24}'}
      end
      if f == 'heavy' then
        s = string.gsub(s, 'font=heavy', '') ; tex.sprint{'\\def\\tmpfn{3}\\def\\tmpsp{.34}'}
      end
      if f == 'wide' then
        s = string.gsub(s, 'font=wide', '') ; tex.sprint{'\\def\\tmpfn{4}\\def\\tmpsp{.4}'}
      end
      if f == 'srir' then
        s = string.gsub(s, 'font=srir', '') ; tex.sprint{'\\def\\tmpfn{5}\\def\\tmpsp{.2}'}
      end
      if f == 'gero' then
        s = string.gsub(s, 'font=gero', '') ; tex.sprint{'\\def\\tmpfn{6}\\def\\tmpsp{.2}'}
      end
      if f == 'black' then
        s = string.gsub(s, 'font=black', '') ; tex.sprint{'\\def\\tmpfn{7}\\def\\tmpsp{.2}'}
      end
      if f == 'thin' then
        s = string.gsub(s, 'font=thin', '') ; tex.sprint{'\\def\\tmpfn{8}\\def\\tmpsp{.16}'}
      end
      if f == 'icel' then
        s = string.gsub(s, 'font=icel', '') ; tex.sprint{'\\def\\tmpfn{9}\\def\\tmpsp{.2}'}
      end
      if f == 'plas' then
        s = string.gsub(s, 'font=plas', '') ; tex.sprint{'\\def\\tmpfn{10}\\def\\tmpsp{.2}'}
      end
    end
  end
  if string.find(s, 'case=') then
    c, n = string.gsub(s, '.*case=', '') ; c = string.gsub(c, ',.*', '')
    s = string.gsub(s, 'title', 'titl')
    if n == 1 then
      if c == 'none' then
        s = string.gsub(s, 'case=none', '') ; tex.sprint('\\def\\tmpcase{0}')
      end
      if c == 'smcp' then
        s = string.gsub(s, 'case=smcp', '') ; tex.sprint('\\def\\tmpcase{1}')
      end
      if c == 'onum' then
        s = string.gsub(s, 'case=onum', '') ; tex.sprint('\\def\\tmpcase{2}')
      end
      if c == 'smon' then
        s = string.gsub(s, 'case=smon', '') ; tex.sprint('\\def\\tmpcase{3}')
      end
      if c == 'titl' then
        s = string.gsub(s, 'case=titl', '') ; tex.sprint('\\def\\tmpcase{4}')
      end
      if c == 'dflt' then
        s = string.gsub(s, 'case=dflt', '') ; tex.sprint('\\def\\tmpcase{5}')
      end
    end
  end
  if string.find(s, 'scale=') then
    x, n = string.gsub(s, '.*scale=', '') ; x = string.gsub(x, ',.*', '')
    if n == 1 and x ~= '' then
      xx = '' .. x -- because tonumber may add preceding 0.
      x = tonumber(x)
      if x and x >= 0.83 and x <= 1 then
        tex.sprint('\\def\\tmpscale{' .. x .. '}')
        s = string.gsub(s, 'scale=' .. xx, '')
      end
    end
  end
  s = string.gsub(s, ',', '')
  if s == '' then
    tex.sprint('\\def\\tmpreturn{1}')
  else
    tex.sprint('\\def\\tmpreturn{0}') ; nvt.good = false
  end
end
--


-- Parse \namestyle, \subnamestyle, and \name, \subname options:
nvt.parsenamestyle = function (s) ----- defer to begin document
  s = s .. ',' ; s = string.gsub(s, ' ', '')
  local n, m, mm, mmm, t, tt, a, f, c, h, d
  local min = 1 ; local max = 4
  if string.find(s, 'scale=') then
    mm, n = string.gsub(s, '.*scale=', '') ; mm = string.gsub(mm, ',.*', '')
    if string.find(mm, 'a$') then
      tex.sprint('\\def\\tmpauto{1}') ; mmm = string.gsub(mm, 'a$', '')
    else
      tex.sprint('\\def\\tmpauto{0}') ; mmm = mm
    end
    m = tonumber(mmm)
    if m and n == 1 and m >= 1 and m <= 4 then
      s = string.gsub(s, 'scale=' .. mm, '') ; tex.sprint('\\def\\tmpscale{' .. m .. '}')
    end
  end
  if string.find(s, 'align=') then
    a, n = string.gsub(s, '.*align=', '') ; a = string.gsub(a, ',.*', '')
    if n == 1 then
      if (a == 'left' or a == 'right' or a == 'center') then
        s = string.gsub(s, 'align=' .. a, '')
      end
      if a == 'left' then tex.sprint('\\def\\tmpalign{1}')
      elseif a == 'right' then tex.sprint('\\def\\tmpalign{2}')
      else tex.sprint('\\def\\tmpalign{0}')
      end
    end
  end
  if string.find(s, 'track=') then
    t, n = string.gsub(s, '.*track=', '') ; t = string.gsub(t, ',.*', '') ; tt = t
    if n == 1 and t ~= '' then
      t = tonumber(t)
      if t and t >= 0 and t <= 9 then
        s = string.gsub(s, 'track=' .. t, '') ; tex.sprint('\\def\\tmptrack{' .. tt .. '}')
      end
    end
  end
  if string.find(s, 'font=') then
    f, n = string.gsub(s, '.*font=', '') ; f = string.gsub(f, ',.*', '')
    if n == 1 then
      if f == 'main' then
        s = string.gsub(s, 'font=main', '') ; tex.sprint{'\\def\\tmpfn{0}\\def\\tmpsp{.21}'}
      end
      if f == 'dark' then
        s = string.gsub(s, 'font=dark', '') ; tex.sprint{'\\def\\tmpfn{1}\\def\\tmpsp{.21}'}
      end
      if f == 'thick' then
        s = string.gsub(s, 'font=thick', '') ; tex.sprint{'\\def\\tmpfn{2}\\def\\tmpsp{.24}'}
      end
      if f == 'heavy' then
        s = string.gsub(s, 'font=heavy', '') ; tex.sprint{'\\def\\tmpfn{3}\\def\\tmpsp{.34}'}
      end
      if f == 'wide' then
        s = string.gsub(s, 'font=wide', '') ; tex.sprint{'\\def\\tmpfn{4}\\def\\tmpsp{.4}'}
      end
      if f == 'srir' then
        s = string.gsub(s, 'font=srir', '') ; tex.sprint{'\\def\\tmpfn{5}\\def\\tmpsp{.2}'}
      end
      if f == 'gero' then
        s = string.gsub(s, 'font=gero', '') ; tex.sprint{'\\def\\tmpfn{6}\\def\\tmpsp{.2}'}
      end
      if f == 'black' then
        s = string.gsub(s, 'font=black', '') ; tex.sprint{'\\def\\tmpfn{7}\\def\\tmpsp{.2}'}
      end
      if f == 'thin' then
        s = string.gsub(s, 'font=thin', '') ; tex.sprint{'\\def\\tmpfn{8}\\def\\tmpsp{.12}'}
      end
      if f == 'icel' then
        s = string.gsub(s, 'font=icel', '') ; tex.sprint{'\\def\\tmpfn{9}\\def\\tmpsp{.2}'}
      end
      if f == 'plas' then
        s = string.gsub(s, 'font=plas', '') ; tex.sprint{'\\def\\tmpfn{10}\\def\\tmpsp{.2}'}
      end
    end
  end
  if string.find(s, 'case=') then
    c, n = string.gsub(s, '.*case=', '') ; c = string.gsub(c, ',.*', '')
    s = string.gsub(s, 'title', 'titl')
    if n == 1 then
      if c == 'none' then
        s = string.gsub(s, 'case=none', '') ; tex.sprint('\\def\\tmpcase{0}')
      end
      if c == 'smcp' then
        s = string.gsub(s, 'case=smcp', '') ; tex.sprint('\\def\\tmpcase{1}')
      end
      if c == 'onum' then
        s = string.gsub(s, 'case=onum', '') ; tex.sprint('\\def\\tmpcase{2}')
      end
      if c == 'smon' then
        s = string.gsub(s, 'case=smon', '') ; tex.sprint('\\def\\tmpcase{3}')
      end
      if c == 'titl' then
        s = string.gsub(s, 'case=titl', '') ; tex.sprint('\\def\\tmpcase{4}')
      end
    end
  end
  s = string.gsub(s, ',', '')
  if s == '' then
    tex.sprint('\\def\\tmpreturn{1}')
  else
    tex.sprint('\\def\\tmpreturn{0}') ; nvt.good = false
  end
end
--


-- Parse \scenestyle and \scene options:
nvt.parsescenestyle = function (s)
  s = s .. ',' ; s = string.gsub(s, ' ', '')
  local n, t, a, f, c, x, xx
  local min = 1 ; local max = 1.5
  if string.find(s, 'scale=') then
    x, n = string.gsub(s, '.*scale=', '') ; x = string.gsub(x, ',.*', '')
    if n == 1 and x ~= '' then
      xx = '' .. x -- because tonumber may add preceding 0.
      x = tonumber(x)
      if x and x >= 0.83 and x <= 1 then
        tex.sprint('\\def\\tmpscale{' .. x .. '}')
        s = string.gsub(s, 'scale=' .. xx, '')
      end
    end
  end
  if string.find(s, 'align=') then
    a, n = string.gsub(s, '.*align=', '') ; a = string.gsub(a, ',.*', '')
    if n == 1 then
      if (a == 'left' or a == 'right' or a == 'center') then
        s = string.gsub(s, 'align=' .. a, '')
      end
      if a == 'left' then tex.sprint('\\def\\tmpscalign{1}')
      elseif a == 'right' then tex.sprint('\\def\\tmpscalign{2}')
      else tex.sprint('\\def\\tmpscalign{0}')
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
    if n == 1 then
      if f == 'main' then
        s = string.gsub(s, 'font=main', '') ; tex.sprint{'\\def\\tmpfn{0}\\def\\tmpsp{.21}'}
      end
      if f == 'dark' then
        s = string.gsub(s, 'font=dark', '') ; tex.sprint{'\\def\\tmpfn{1}\\def\\tmpsp{.21}'}
      end
      if f == 'thick' then
        s = string.gsub(s, 'font=thick', '') ; tex.sprint{'\\def\\tmpfn{2}\\def\\tmpsp{.24}'}
      end
      if f == 'heavy' then
        s = string.gsub(s, 'font=heavy', '') ; tex.sprint{'\\def\\tmpfn{3}\\def\\tmpsp{.34}'}
      end
      if f == 'wide' then
        s = string.gsub(s, 'font=wide', '') ; tex.sprint{'\\def\\tmpfn{4}\\def\\tmpsp{.4}'}
      end
      if f == 'srir' then
        s = string.gsub(s, 'font=srir', '') ; tex.sprint{'\\def\\tmpfn{5}\\def\\tmpsp{.2}'}
      end
      if f == 'gero' then
        s = string.gsub(s, 'font=gero', '') ; tex.sprint{'\\def\\tmpfn{6}\\def\\tmpsp{.2}'}
      end
      if f == 'black' then
        s = string.gsub(s, 'font=black', '') ; tex.sprint{'\\def\\tmpfn{7}\\def\\tmpsp{.2}'}
      end
      if f == 'thin' then
        s = string.gsub(s, 'font=thin', '') ; tex.sprint{'\\def\\tmpfn{8}\\def\\tmpsp{.12}'}
      end
      if f == 'icel' then
        s = string.gsub(s, 'font=icel', '') ; tex.sprint{'\\def\\tmpfn{9}\\def\\tmpsp{.2}'}
      end
      if f == 'plas' then
        s = string.gsub(s, 'font=plas', '') ; tex.sprint{'\\def\\tmpfn{10}\\def\\tmpsp{.2}'}
      end
    end
  end
  if string.find(s, 'case=') then
    c, n = string.gsub(s, '.*case=', '') ; c = string.gsub(c, ',.*', '')
    s = string.gsub(s, 'title', 'titl')
    if n == 1 then
      if c == 'none' then
        s = string.gsub(s, 'case=none', '') ; tex.sprint('\\def\\tmpcase{0}')
      end
      if c == 'smcp' then
        s = string.gsub(s, 'case=smcp', '') ; tex.sprint('\\def\\tmpcase{1}')
      end
      if c == 'onum' then
        s = string.gsub(s, 'case=onum', '') ; tex.sprint('\\def\\tmpcase{2}')
      end
      if c == 'smon' then
        s = string.gsub(s, 'case=smon', '') ; tex.sprint('\\def\\tmpcase{3}')
      end
      if c == 'titl' then
        s = string.gsub(s, 'case=titl', '') ; tex.sprint('\\def\\tmpcase{4}')
      end
    end
  end
  s = string.gsub(s, ',', '')
  if s == '' then
    tex.sprint('\\def\\tmpscreturn{1}')
  else
    tex.sprint('\\def\\tmpscreturn{0}') ; nvt.good = false
  end
end
--


-- Parse \footnotestyle:
nvt.parsefnstyle = function (s)
  local ind
  s = string.gsub(s, ' ', '') ; s = s .. ','
  ind = string.gsub(s, '.*indent=', '') ; ind = string.gsub(ind, ',.*', '')
  if ind == 'near' or ind == '' then tex.sprint('\\def\\tmpind{0}')
  elseif ind == 'away' then tex.sprint('\\def\\tmpind{1}')
  elseif ind == 'both' then tex.sprint('\\def\\tmpind{2}')
  elseif ind == 'none' then tex.sprint('\\def\\tmpind{3}')
  elseif ind ~= '' then tex.sprint('\\def\\tmpreturn{0}') ; nvt.good = false
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


-- Parse \devcode:
function nvt.parsedevcode (s) -- s is filename.tex
  local ok = true
  s = string.gsub(s,' ','') -- utf-8 ?
  if string.find(s,'/') then ok = false end -- utf-8 ?
  if not string.find(s,'%.tex$') then ok = false end -- utf-8 ? -- *.lua ?
  if ok == true then
    tex.sprint('\\def\\tmpreturn{1}')
  else
    nvt.good = false ; tex.sprint('\\def\\tmpreturn{0}')
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
  local l, r, text, ind, off, a, n
  s = string.gsub(s, ' ', '') ; s = s .. ','
  text, n = string.gsub(s, '.*text=', '') ; text = string.gsub(text, ',.*', '')
  if n == 1 then
    if d == "D" then
      if text == 'normal' then
        tex.sprint('\\def\\tmpt{0}') ; s = string.gsub(s, 'text=normal', '')
      elseif text == 'small' then
        tex.sprint('\\def\\tmpt{1}') ; s = string.gsub(s, 'text=small', '')
      end
    else
      if text == 'small' then tex.sprint('\\def\\tmpt{2}') end
    end
  end
  ind, n = string.gsub(s, '.*indent=', '') ; ind = string.gsub(ind, ',.*', '')
  if n == 1 then
    if ind == '0' then tex.sprint('\\def\\tmpind{0}') ; s = string.gsub(s, 'indent=0', '')
    elseif ind == '1' then tex.sprint('\\def\\tmpind{1}') ; s = string.gsub(s, 'indent=1', '')
    end
  end
  a, n = string.gsub(s, '.*align=', '') ; a = string.gsub(a, ',.*', '')
  if n == 1 then
    if a == 'justify' then tex.sprint{'\\def\\tmpa{0}'} ; s = string.gsub(s, 'align=justify', '')
    elseif a == 'center' then tex.sprint{'\\def\\tmpa{1}'} ; s = string.gsub(s, 'align=center', '')
    elseif a == 'left' then tex.sprint{'\\def\\tmpa{2}'} ; s = string.gsub(s, 'align=left', '')
    elseif a == 'right' then tex.sprint{'\\def\\tmpa{3}'} ; s = string.gsub(s, 'align=right', '')
    end
  end
  off, n = string.gsub(s, '.*offset=', '') ; off = string.gsub(off, ',.*', '')
  if n == 1 then
    l = string.gsub(off, '/.*', '') ; local ln = tonumber(l)
    r = string.gsub(off, '.*/', '') ; local rn = tonumber(r)
    if ln and rn and ln > 0 and rn >= 0 and ln <= 8 and rn <= 8 and (ln + rn) <= 12 then
      tex.sprint('\\def\\tmpl{' .. l .. '}\\def\\tmpr{' .. r .. '}')
      s = string.gsub(s, 'offset=' .. l .. '/' .. r, '')
    end
    if l == 's' and (r == 's' or r == '0') then
      tex.sprint('\\def\\tmpl{' .. l .. '}\\def\\tmpr{' .. r .. '}')
      s = string.gsub(s, 'offset=' .. l .. '/' .. r, '')
    end
  end
  s = string.gsub(s, ',', '')
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
  if string.find(s1, 'legal,') then
    tex.sprint('\\def\\tmplegal{1}\\def\\tmprecto{0}\\def\\tmpsingle{1}')
    tex.sprint('\\def\\tmptps{empty}\\def\\tmpguide{0}')
    s1 = '' -- other options ignored.
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
  if string.find(s1, 'thispagestyle=') then
    local p, n = string.gsub(s1, '.*thispagestyle=', '') ; p = string.gsub(p, ',.*', '')
    if n == 1 and (p == 'empty' or p == 'plain' or p == 'fakeplain' or p == 'max') then
      tex.sprint('\\def\\tmptps{' .. p .. '}') ; s1 = string.gsub(s1, 'thispagestyle=' .. p, '')
    end
  end
  s1 = string.gsub(s1, ',', '')
  if s1 == '' then
    tex.sprint('\\def\\tmpreturn{1}')
  else
    tex.sprint('\\def\\tmpreturn{0}') ; nvt.good = false
  end
end
--


-- Attribution: Code by user "topskip". Simpler than full-scale code from other packages.
-- Prevents line wrap ending on single letter. You can still manually break using \\.
-- This is mandatory in some languages, desirable in others (such as English).
nvt.prevent_single_letter = function(head)
  while head do
    if head.id == 37 and unicode.utf8.match(unicode.utf8.char(head.char),'%a') then
      if head.prev.id == 10 and head.next.id == 10 then
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
-- contains unmatched parentheses, big problem. This enforces matched parentheses, if any used.
function nvt.parsemeta(str,which)
  local sp = string.gsub(str, '[^%(%)]', '') -- Check for unbalanced or nested parentheses.
  sp = string.gsub(sp, '%(%)', '') -- As above.
  if string.len(sp) > 0 then
    tex.sprint('\\def\\tmpreturn{0}')
  else
    str = string.gsub(str, '^ ', '') ; str = string.gsub(str, ' $', '')
    str = string.gsub(str, '\\', '')
    if which == 'title' then
      nvt.title = '' .. str ; tex.sprint('\\def\\tmptitle{' .. str .. '}')
    elseif which == 'author' then
      nvt.author = '' .. str ; tex.sprint('\\def\\tmpauthor{' .. str .. '}')
    elseif which == 'subtitle' then
      nvt.subtitle = '' .. str ; tex.sprint('\\def\\tmpsubtitle{' .. str .. '}')
    elseif which == 'version' then
      nvt.version = '' .. str ; tex.sprint('\\def\\tmpversion{' .. str .. '}')
    end
    tex.sprint('\\def\\tmpreturn{1}')
  end
end
--


-- Parse \docdate:
-- The docdate format is yyyy/mm/dd but the range of numbers is not checked. This changes
-- the string from your easy-to-read setting, to the string format used within PDF.
function nvt.parsedocdate (s)
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
--


-- Parse \trimsize setting:
function nvt.parsetrimsize (s)
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
          tex.sprint('\\def\\tmptw{' .. wd .. 'in}')
          s = string.gsub(s, 'width=' .. wd .. 'in', '')
          tex.sprint('\\def\\tmpth{' .. ht .. 'in}')
          s = string.gsub(s, 'height=' .. ht .. 'in', '')
          nvt.trimwidth = wd*nvt.inch ; nvt.trimheight = ht*nvt.inch          
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
            tex.sprint('\\def\\tmptw{' .. wd .. 'mm}')
            s = string.gsub(s, 'width=' .. wd .. 'mm', '')
            tex.sprint('\\def\\tmpth{' .. ht .. 'mm}')
            s = string.gsub(s, 'height=' .. ht .. 'mm', '')
            nvt.trimwidth = wd*nvt.mm ; nvt.trimheight = ht*nvt.mm
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
--


-- Parse \layout setting:
function nvt.parselayout (s)
  s = s .. ',' ; s = string.gsub(s, ' ' ,'')
  local p, l, n, g, c ; local ok = true
  if string.find(s, 'pagestyle=') then
    p, n = string.gsub(s, '.*pagestyle=', '') ; p = string.gsub(p, ',.*', '')
    if n == 1 and string.find(':none:plain:center:margin:marcen:split:', ':' .. p .. ':') then
      tex.sprint('\\def\\tmpps{' .. p .. '}') ; nvt.pagestyle = p
      s = string.gsub(s, 'pagestyle=' .. p, '')
      if p == 'none' then nvt.header = false ; nvt.footer = false
      elseif p == 'plain' then nvt.header = false ; nvt.footer = true
      elseif p == 'split' then nvt.header = true ; nvt.footer = true
      else nvt.header = true ; nvt.footer = false
      end
    end
  end
  if string.find(s, 'lines=') then
    l, n = string.gsub(s, '.*lines=', '') ; l = string.gsub(l, ',.*', '') ; l = tonumber(l)
    if n == 1 and l and l >= 26 and l <= 35 and math.floor(l) == l then
      nvt.lines = l ; tex.sprint('\\def\\tmplines{' .. l .. '}')
      s = string.gsub(s, 'lines=' .. l, '')
    end
  end
  if string.find(s, 'glue=') then
    g, n = string.gsub(s, '.*glue=', '') ; g = string.gsub(g, ',.*', '')
    if n == 1 then
      if g == 'wide' or g == 'normal' then s = string.gsub(s, 'glue=' .. g, '') end
      if g == 'wide' then nvt.moreglue = true ; tex.sprint('\\def\\tmpmoreglue{1}') end
    end
  end
  if string.find(s, 'cpl=') then
    c, n = string.gsub(s, '.*cpl=', '') ; c = string.gsub(c, ',.*', '')
    if n == 1 then
      c = tonumber(c)
      if c and c >= 62 and c <= 70 then
        nvt.charperline = c ; tex.sprint('\\def\\tmpc{' .. c .. '}')
        s = string.gsub(s, 'cpl=' .. c, '')
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
--


-- Parse pdfx setting:
function nvt.parsepdfx (s)
  s = string.gsub(s, ' ', '') ; s = string.gsub(s, ',' ,'')
  if nvt.lang == 'usenglishmax' or nvt.lang == 'en' then nvt.oi = 'swop' else nvt.oi = 'fogra' end
  if string.find(s, 'swop') then nvt.oi = 'swop' ; s = string.gsub(s, 'swop', '')
  elseif string.find(s, 'fogra') then nvt.oi = 'fogra' ; s = string.gsub(s, 'fogra' ,'')
  elseif string.find(s,'off') then nvt.pdfx = false ; nvt.oi = '' ; s = string.gsub(s, 'off', '')
  end
  if s == '' then
    tex.sprint('\\def\\tmpreturn{1}\\def\\tmpoi{' .. nvt.oi .. '}')
  else
    tex.sprint('\\def\\tmpreturn{0}') ; nvt.pdfx = false ; nvt.good = false
  end
end
--


-- Parse \lang setting:
nvt.parselang = function (s)
  s = string.gsub(s, ' ', '') ; s = string.gsub(s, '%-', '')
  local ok = false ; local k = 1
  s = string.lower(s)
  if string.find(s, '^en') then nvt.lang = 'british' ; ok = true end
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
  if ok == true then
    tex.sprint('\\def\\tmplang{' .. nvt.lang .. '}\\def\\tmpreturn{' .. k .. '}')
  else
    nvt.lang = 'english' ; nvt.good = false ; tex.sprint('\\def\\tmpreturn{0}')
  end
end
--


-- Parse \enable setting(s):
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
        s = string.gsub(s, 'guide=' .. g, '')
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


-- Parse disable setting(s):
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
  if string.find(s,'oldstyle,') then
    tex.sprint('\\def\\tmpnooldstyle{1}') ; s = string.gsub(s, 'oldstyle', '')
  end
  if string.find(s,'autodeco,') then
    tex.sprint('\\def\\tmpnoautodeco{1}') ; s = string.gsub(s, 'autodeco', '')
  end
  if string.find(s,'metasub,') then
    tex.sprint('\\def\\tmpnometasub{1}') ; s=string.gsub(s,'metasub','')
  end
  s=string.gsub(s, ',', '')
  if s ~= '' then
    nvt.good = false ; tex.sprint('\\def\\tmpreturn{0}')
  else
    tex.sprint('\\def\\tmpreturn{1}')
  end
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
