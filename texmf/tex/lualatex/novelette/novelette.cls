%% This is file 'novelette.cls', part of Novelette document class.
%%
%% VERSIONS PRIOR TO 1.0 ARE UNFINISHED !!!
%%
%%
%% Copyright 2026 Terry Lebragleo (anagram for original developer's real name).
%% Project Page: github.com/lebragleo/novelette. Contact via 'issues' there.
%%
%% LICENSES
%%   Different licenses apply to the various files collectively distributed as Novelette.
%% Some files contain attributions to code provided or suggested by others, under terms of the
%% LaTeX Project Public License (LPPL) v.1.3. That license allows re-licensing to the MIT License.
%% Where such code is used, its attribution must be retained, unless the code is removed.
%%
%% License for fonts:
%%   The SIL Open Font License, without Reserved Font Name. A copy of this license is included
%% in the same folder as the Novelette OpenType fonts, and is also available at
%% https://openfontlicense.org.
%%
%% License for all Novelette files, other than fonts:
%% The MIT License
%%   Permission is hereby granted, free of charge, to any person obtaining a copy
%%   of this software and associated documentation files (the "Software"), to deal
%%   in the Software without restriction, including without limitation the rights
%%   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%%   copies of the Software, and to permit persons to whom the Software is
%%   furnished to do so, subject to the following conditions:
%%
%%   The above copyright notice and this permission notice shall be included in all
%%   copies or substantial portions of the Software.
%%
%%   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%%   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%%   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%%   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%%   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%%   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
%%   SOFTWARE.
%% End MIT License.



%% NOTES for developers and maintainers:
%%   Except for code copied into 'novelette-fonts.sty', Novelette does not use ExplSyntax.
%% This is because there is no problem with argument expansions, or *.aux file. The code has been
%% written to be as obvious as possible. Please keep it that way! Remember that the intended
%% users are writers, not programmers.
%%   The original developer's text editor provides better colors when comments are double %%
%% instead of just one. That's why you see %% everywhere. It is not necessary for the code.
%% Yet is a good idea for everyone, since %% is more visible than just one.
%%   A lot of effort has been made, to provide error and warning messages that are less baffling
%% than some standard LaTeX messages.
%%   Please avoid 'feature creep'. Novelette does what it needs to do, and no more, for the
%% intended usage in original popular fiction. Looking through many of the recently-published
%% books in the local public library (mystery, crime, romance, sci-fi) nearly all of them
%% have book design that can be produced by Novelette. The ones that do not, are unimportant.
%%   Novelette does not use class options to set anything. Instead, settings are performed
%% by commands in Preamble. However, to accomodate the possibility that there may be versions
%% of Novelette with different behavior, class option [variant=value] is allowed. The value may be
%% any ASCII alphanumeric string without spaces or special characters. It should be distinctive,
%% so that variants proposed by someone are not confused with variants proposed by someone else.
%% The value is stored as global \nvt@clsvar. For example, [variant=JaneK32] might indicate that
%% it was provided by developer JaneK. Then, where the variant is used, it could be tested,
%% with code forked according to its value, like this:
%%         \def\tmpvar{JaneK32}\ifx\nvt@clsvar\tmpvar\DoThis\else\DoThat\fi
%%

\NeedsTeXFormat{LaTeX2e}[2025/01/01] %% Requires TeX 2025 or later.
\ProvidesClass{novelette}[2026/08/20 v0.1.3^^JLuaLaTeX document class, original popular fiction.]

%% OVERVIEW:
%%   Novelette is intended for one thing only: original popular fiction, printed. What that means:
%%     original -> Your own, new work. Not a reprint or critique of someone else's work.
%%       For best typesetting, you will need to re-write problem areas. That's easy to do when
%%       the work is your own, but often impossible if you must retain some other text.
%%     popular -> Murder mysteries, science fiction, romance. Things like that.
%%     fiction -> Not non-fiction, unless its style is like fiction. Novelette lacks
%%       support for the kind of references and citations needed for non-fiction. 
%%     printed -> To book, especially using print-on-demand. Not Ebook (do that separately).
%%   For detailed explanations of the various settings and macro commands, look into the
%% several 'novelette-X.sty' files, for topic X.
%%   Novelette does not use an *.aux file. Compiling never requires a double-run. This reduces
%% the likelihood of issues caused by writer/editor text exchange. But it also means that some
%% standard LaTeX features, such as automatic Table of Contents, do not exist; if you need them,
%% you must create them manually.
%%   Other than the [variant=value] for developers, Novelette has no class options. All settings
%% are performed in Preamble, using commands for that purpose.
%%   In Preamble, most LaTeX special characters retain their special meaning, and must be escaped
%% if they are used. But in the document body, # $ ^ _ & are ordinary, printing characters.
%% No harm if they are backslashed, but not necessary. Since $ is ordinary, no math mode!
%%


%% ESSENTIALS:
\def\nvt@where{In Preamble.} %% Re-defined later.
\long\def\nvt@fatal#1{%%
  \typeout{^^J^^JNOVELETTE FATAL ERROR: \nvt@where^^J\spii #1^^J}\batchmode \read-1 to \sorry%%
}%%
\IfDocumentMetadataTF{%%
  \nvt@fatal{\string\DocumentMetadata\space not allowed in Novelette.^^J%%
    Use only Novelette-specific metadata settings in Preamble:^^J%%
    \string\title\space and \string\author\space are required.^^J%%
    \string\subtitle, \string\pdfx, \string\version, and \string\docdate\space are optional.}%%
}{}%%
\def\nvt@expdet#1{\expandafter\detokenize\expandafter{#1}} %% Those characters become catcode 12.
\edef\nvt@now{\nvt@expdet{\pdffeedback creationdate}} %% Date and time at compile. Format D:---
\def\spii{\space\space}\def\spiv{\spii\spii}\def\spix{\spiv\spiv\space}
\ifdefined\directlua
  \IfFileExists{\jobname.typo}{%%
    \directlua{%%
      local fileout = tex.jobname .. '.typo'
      local out = io.open(fileout,"w+")
      out:write('This file has been cleared by compiling without \\enable{examine}.')
      io.close(out)
    }%%
  }{}%%
  \directlua{%%
    nvt = nvt or { }
    nvt.now = '\luaescapestring{\nvt@now}'
    require 'novelette-luasupport'
    nvt.parseclass('\luaescapestring{\@classoptionslist}')
  }%%
  \ifnum\tmpreturn=0\relax
    \nvt@fatal{Unknown class option(s). Novelette uses settings in Preamble.^^J}
  \fi
\else
  \nvt@fatal{Novelette documents must be processed by lualatex.^^J}
\fi
\def\documentclass{%%
  \nvt@fatal{Cannot repeat \string\documentclass.^^J%%
    Did you write \string\documentclass\string within a subdoc file? Don't do that.^^J}
}%%
\def\LoadClass{\nvt@fatal{\string\LoadClass\space cannot be used in Novelette.^^J}}
\pdfvariable suppressoptionalinfo 1023 %% Only write Info specific to Novelette.
%% Later: \pdfvariable trailerid
\pdfvariable majorversion=1\relax
\pdfvariable minorversion=3\relax %% Required for PDF/x-1a:2001.
\pdfvariable compresslevel=0\relax
\pdfvariable objcompresslevel=0\relax
\pdfvariable imageresolution=300\relax %% If image does not state its resolution.
\protected\def\pdfobj{\pdfextension obj } %% Compatibility.
\protected\def\pdflastobj{\numexpr\pdffeedback lastobj\relax} %% Compatibility.
\protected\edef\pdfpageattr{\pdfvariable pageattr} %% Compatibility.
\nofiles %% *.aux not needed, since double-compile not used.
\newif\ifcolors@ %% Always false. Possible compatibility.
\def\nvt@test#1#2#3#4{%%
  \edef\tmptesta{\nvt@expdet{#1}}%%
  \edef\tmptestb{\nvt@expdet{#2}}%%
  \ifx\tmptesta\tmptestb#3\else#4\fi%%
}%%
\def\nvt@filepath{./} %% Re-defined when compiling subdoc.
\def\nvt@nowcompiling{} %% Empty for main doc, nonempty for \subdoc.
\def\nvt@zrule{\rule{0pt}{0pt}} %% Provides anchor point for various fill commands.
%%


%% PAGE NUMBERING:
%%   In Novelette, there are two counters for page numbering, {page} is pre-defined by LaTeX,
%% and is never reset by Novelette. Counter {nvt@bookpage} resets at the transition from
%% frontmatter to mainmatter, unless you \disable{recount}.
%%   Any PDF reader software sees page numbers as the arabic value of {page}. So if your book
%% has 278 pages, including front/main/backmatter and blanks, the 'PDFpage' numbers are 1 to 278.
%% If you compile a subdoc file, 'PDFpage' 1 is generally not the first page of the whole book.
%%   In frontmatter, page numbers usually do not print. But if printed, the numerals are
%% lowercase roman {nvt@bookpage}.
%%   In mainmatter, printed page numbers are arabic (nvt@bookpage). In backmatter, page numbers
%% usually do not print; but if printed, they continue without reset, as arabic.
%%   When compiling a subdoc file, the true page numbers are unknown, since the subdoc
%% is often not at the start of the book. In this case, the 'PDFpage' still starts at 1.
%% But printed page numbers will be zzz in frontmatter, or 000 elsewhere. Also, since it is not
%% known whether subdoc pages are recto or verso, the spine glue strip width is split
%% to left and right, rather than alternating by recto/verso.
%%   Error and warning messages refer to the 'PDFpage' number.
\def\thepage{\arabic{page}} %% Default. Likely to be changed by your document.
\newcounter{nvt@pageoffset} %% Value of {page} counter, at frontmatter/mainmatter transition.
\newcounter{nvt@bookpage} %% Value of printable page number. May print roman/arabic.
\newcounter{nvt@expectpage}\setcounter{nvt@expectpage}{1} %% PDFpage number "expected" to happen.
%%


%% CALCULATIONS AND ADDITIONAL INPUTS:
%%   At the end of Preamble, your settings and defaults are passed to Lua. Various sanity checks
%% and calculations are performed. The results are passed back to LaTeX, where standard variables
%% such as font em size, baselineskip, margins, headheight, and others are set. They must be set
%% before LaTeX performs its own AtBeginDocument routines.
%%   Some packages must know those settings, before they load.
\RequirePackage{novelette-errwarnban} %% Custom errors, warnings, and banned LaTeX commands.
\newif\ifnvt@incomponent %% True within component environment.
\newif\ifnvt@wantdark %% Refers to font; also following lines:
\newif\ifnvt@wantthick
\newif\ifnvt@wantheavy
\newif\ifnvt@wantblack
\newif\ifnvt@wantwide
\newif\ifnvt@wantthin
\newif\ifnvt@wantsrir
\newif\ifnvt@wantgero
\newif\ifnvt@wanticel
\newif\ifnvt@wantplas
\let\nvt@par\par\relax %% For local \par tweaks.
\let\nvt@brk\\\relax %% For break tweaks.
\let\nvt@input\input\relax %% For internal use only, where \input is deactivated.
\let\nvt@maybestopnow\relax%% Changes when compiling only subdocs.
\catcode`\_=12\relax %% So that _ may be used as text anywhere.
\RequirePackage{novelette-settings} %% Preamble settings.
\AddToHook{begindocument/before}{%%
  \let\language\orig@language\relax
  \typeout{Info: Completed Preamble. Now processing its settings.}
  \setlength\hoffset{-1in}\setlength\voffset{-1in} %% Removes built-in LaTeX offsets.
  \RequirePackage{novelette-components,novelette-graphics,novelette-effects,novelette-layout}
  \nvt@processlayout %% In novelette-layout.sty.
  \let\nvt@RequirePackage\RequirePackage\relax
  \RequirePackage{novelette-subdocs}
  \setlength\pagewidth{\nvt@trimwidth}\setlength\pageheight{\nvt@trimheight}
  \setlength\paperwidth{\pagewidth}\setlength\paperheight{\pageheight}
  \renewcommand\normalsize{\@setfontsize\normalsize\nvt@em\nvt@bls}%% Calculated from settings.
  \normalsize
  \let\input\nvt@noinput\relax %% Prevents added packages or other user-loaded files in Preamble.
  \ifnvt@draft\else\nvt@examinefalse\fi
  \let\input\nvt@input\relax\let\RequirePackage\nvt@RequirePackage\relax
  \RequirePackage{luahyphenrules}\HyphenRules{\nvt@lang}%% Load after \normalsize.
  \def\HyphenRules#1{\nvt@err{Only one \string\HyphenRules\space is allowed.}}
  \ifx\nvt@TrimBox\@empty\else
    \begingroup\edef\nvt@AddTrimBox{\endgroup\pdfpageattr{\nvt@TrimBox}}\nvt@AddTrimBox
  \fi
  \RequirePackage{novelette-fonts,novelette-metadata}
  \ifnvt@examine
    \directlua{require('novelette-examine')}
    \nvt@luagray%% In novelette-graphics.sty.
    \begingroup\nvt@gray6
    \directlua{nvt.tbl[1]=\the\LuaGray@Attribute ; GRAY=nvt.tbl[1]}
    \endgroup
  \else
    \def\color{\nvt@nocolorcmd{\string\color}}
    \def\textcolor{\nvt@nocolorcmd{\string\textcolor}}
    \def\pagecolor{\nvt@nocolorcmd{\string\pagecolor}}
    \def\definecolor{\nvt@nocolorcmd{\string\definecolor}}
  \fi
  \ifnvt@didversohead\else\def\nvt@versohead{\thetitle}\fi
  \ifnvt@didrectohead\else\def\nvt@rectohead{\theauthor}\fi
  \def\input#1{}
}%%
%%


%% GETTING READY FOR DOCUMENT BODY:
%%   After LaTeX performs its own AtBeginDocument routines, these are added, so that they
%% are effective in the document body. Particularly note that math-mode commands, which might
%% have been internally used by LaTeX, will now be neutralized.
%%   If you have expertise, you may create a file containing your own code. Its file name must
%% have extension '.tex' or '.lua' (not '.sty' or anything else). It must be located in folder
%% 'devcode' relative to main document. In Preamble, use \devcode{filename.ext}. That does not
%% load your code immediately, but loads that file at the last step before reading the
%% document body. Your code may use # for macro arguments, but @ is ordinary there, so you
%% may need to use \makeatletter ... \makeatother in your code.
\AddToHook{begindocument/end}{%%
  \AddToHook{shipout/before}{\stepcounter{nvt@bookpage}}
  \nvt@defineindent%% Set normal paragraph indent.
  \def\forceindent{\hspace*{\nvt@parindent}}%% May be useful when parindent=0pt.
  \ifnvt@dev\nvt@devshade\fi%% Developer-mode shading.
  \nvt@definepagestyles%% In novelette-layout.sty.
  \@nameuse{ps@\nvt@pagestyle}%% Chooses the page style.
  \nvt@checkversohead{\nvt@versohead}\nvt@checkrectohead{\nvt@rectohead}%% Ensure they fit.
  \nvt@inmainmattertrue%% For documents that do not use frontmatter.
  \catcode`\$=12\relax%% A nickel is a nickel, a dime is a dime, a $ is a dollar. No math mode.
  \def\({\char"0028}
  \def\){\char"0029}
  \def\[{\char"005B}
  \def\]{\char"005D}
  \def\ensuremath#1{\nvt@warn{\string\ensuremath\space undefined in Novelette.}#1}%%
  \catcode`\&=12\relax%% The purpose of a table is to wine & dine & have a good time.
  \catcode`\^=12\relax%% No superscripts. Another method is used for footnote markers.
  \ifdefined\nvt@devcode
    \typeout{Info: Loading file defined by \string\devcode.}
    \typeout{\spii If LaTeX throws an error or warning here, it is in your own code.}
    \nvt@input{\nvt@filepath/devcode/\nvt@devcode}
    \typeout{Info: Finished loading file defined by \string\devcode.^^J}
  \fi
  \def\nvt{%% Note: LaTeX automatically sets @ to catcode 12, immediately after \documentclass.
    \nvt@fatal{Detected use of forbidden \string\nvt\space command.^^J%%
      \spii This occurs when you issue a command such as \string\nvt@something,^^J%%
      \spii in a location where the @ character has the wrong catcode.^^J%%
      \spii Or, you attempted to define \string\nvt\space in your own code.}%%
  }%%
  %% catcodes for \ { } % are unchanged. The ~ is redefined in novelette-fonts.sty.
  \catcode`\#=12\relax%% No longer a macro argument number.
  %% NoveletteSerif12-Regular font feature 'unic' substitutes an over-sized character for any
  %% that is not in the allowed metadata set. The metadata is boxed, and the box is measured:
  \typeout{Info: Now creating test page (will be discarded).}%% Checks your metadata text.
  \DiscardShipoutBox
  \ifdefined\nvt@thisdoc\else
    \begingroup\makeatletter
    \nvt@aff{RawFeature={-calt,-liga,-dlig,+hlig,+unic},Scale=.1}
    \sbox0{\thetitle\space\theauthor\space\thesubtitle\space\theversion}
    \usebox0\par
    \edef\tmpa{\fpeval{\dp0 > (.024*\nvt@em)}}
    \ifnum\tmpa=1\relax
      \nvt@fatal{Bad character(s) in one or more of title, author, subtitle, version.^^J%%
        \spii Something is not in Novelette's allowed character set for metadata.^^J%%
        \spii You must use backlash with \string\@\space \# \$ \% \& in metadata.^^J%%
        \spii You may not use backslash for anything else, such as \string\'e for é.^^J%%
        \spii You may not use double quotes or guillemets, or most other symbols.^^J%%
        \spii For other possibilities: See Novelette docs, for complete explanation.}
    \fi
    \edef\tmpa{\fpeval{\wd0 > (.8\textwidth)}}
    \ifnum\tmpa=1\relax
      \nvt@fatal{The combined number of characters in title, author, subtitle, and version^^J%%
        \spii exceeds Novelette's capability. The limit varies, according to your settings,^^J%%
        \spii but is about 240 characters. That's far more than realistically needed.^^J%%
        \spii Probably, you wrote a subtitle that is absurdly long. Make it shorter!}%%
    \fi
    \endgroup
  \fi
    Line breaks within the first typeset paragraph may depend on whether anything was previously
    typeset. Surprising. No known reason. Can make a difference when compiling only subdocs.
    This typesets a dummy paragraph, then discards the page and resets the page counter.\par%%
  \clearpage
  \setcounter{nvt@expectpage}{1}\setcounter{page}{1}\setcounter{nvt@bookpage}{1}
  \ifdefined\nvt@submatter\nvt@submatter\else\clearpage\fi %% Set by subdoc.
  \tracinglostchars=3\relax
  \ifnvt@examine
    \directlua{%%
      nvt.callback('pre_shipout_filter',nvt.check_page,'check_page',1)
      return nvt.check_page
    }%%
  \fi
  \directlua{nvt.preamble=0}
  \ifdefined\nvt@thisdoc
    \typeout{Info: Now beginning the subdoc.^^J}
    \nvt@input{\nvt@filepath\nvt@thisdocpath/\nvt@thisdoc}
    \let\nvt@maybestopnow\enddocument%% Prints only subdoc and its own subdocs.
  \else
    \typeout{Info: Now beginning the document body.^^J}
  \fi
  \nvt@maybestopnow
}%%
%%


%% AFTER TYPESETTING:
%%   This is where the title is be modified, when not a good final-mode PDF. Then, metadata
%% is written to Info and/or XMP. Finally, a summary report is prepared.
\AtEndDocument{%%
  \clearpage
  \let\\\nvt@brk\relax
  \ifnvt@noblankend\else
    \ifodd\c@page\nvt@thispagestyle{empty}\null\clearpage\fi
  \fi
  \nvt@blankverso
  \let\input\nvt@input\relax
  \nvt@didprinttrue
  \ifnum\currentgrouplevel>\z@\relax\directlua{nvt.good = false}\fi
  \ifdefined\nvt@thisdoc
    \typeout{Info: Omitted text beyond subdoc, skipped to end of document body.}
  \else
    \typeout{Info: Reached end of the document body.}
  \fi
  \directlua{nvt.finalize()}
  \nvt@test{\tmpmode}{bad}{\def\nvt@titleprefix{BAD: }}{}
  \ifnvt@didnext
    \nvt@test{\tmpmode}{preview}{\def\tmpmode{draft}}{}
    \nvt@test{\tmpmode}{final}{\def\tmpmode{draft}}{}
  \fi
  \nvt@test{\tmpmode}{final}{}{\nvt@pdfxfalse\def\nvt@oi{none}\nvt@xmpfalse}
%%  \def\tmptest{bad}\ifx\tmpmode\tmptest\def\nvt@titleprefix{BAD: }\fi
%%  \def\tmptest{final}\ifx\tmpmode\tmptest\else\nvt@pdfxfalse\def\nvt@oi{none}\nvt@xmpfalse\fi
  \ifnvt@examine
    \directlua{%%
      local fileout = tex.jobname .. '.typo'
      local out = io.open(fileout,"w+")
      out:write(nvt.buffer)
      io.close(out)
   }%%
  \fi
  \nvt@writepdfinfo
  \ifnvt@pdfx\nvt@declareoutputintent\fi
  \ifnvt@xmp\nvt@addxmp\fi
  \nvt@test{\nvt@titleprefix}{BAD: }{
%%  \def\tmptest{BAD: }\ifx\nvt@titleprefix\tmptest
    \def\nvt@hastalavistababy{%%
      \nonstopmode%%
%%      \errmessage{Fix errors, warnings, overfull boxes, and other problems.}%%
    }
  }{
%%  \else
    \let\nvt@hastalavistababy\relax
%%  \fi
  }
  \nvt@hastalavistababy
}%%
%%


%%
%% End of file novelette.cls
%%
