#!/bin/sh -e

# Fetches the source checkouts in work/src. Later steps build from them.
git submodule update --init --recursive
