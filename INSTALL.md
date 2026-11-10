# How to install Novelette

At this time, Novelette is not yet ready for production. Do not install it unless you
are a developer-level tester.

To install, copy the texmf directory into your TEXMFHOME directory. Then run:

luaotfload-tool --cache=erase

luaotfload-tool -u

To test it, compile this with lualatex:

\documentclass{novelette}

\begin{document}

Hello, World.

\end{document}

