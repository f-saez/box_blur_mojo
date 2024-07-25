#!/bin/bash

echo "remember, libblend2d.so should be in your library path"

mojo package blend2d -I ./blend2d -o validation/blend2d.mojopkg

cd validation
mojo validation.mojo
rm -f blend2d.mojopkg
cd ..

