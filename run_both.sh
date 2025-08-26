#!/usr/bin/env bash

set -ex

LF11=$HOME/.pixi/envs/lf/bin
LF20=$HOME/.pixi/envs/lf/bin

(cd b11 && $LF11/ninja)
(cd b20 && $LF20/ninja)
