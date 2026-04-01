#!/usr/bin/env bash
set -euo pipefail

awk '/^\/dev\/disk/ {print $1; exit}'

