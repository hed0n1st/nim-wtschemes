@echo off
%NIMPATH%\dist\mingw32\bin\windres -O coff wtschemes.rc -o wtschemes32.res
%NIMPATH%\dist\mingw64\bin\windres -O coff wtschemes.rc -o wtschemes64.res

