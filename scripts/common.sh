#!/bin/bash
set -e

log() {
  echo "[INFO] $1"
}

fail() {
  echo "[ERROR] $1"
  exit 1
}

require_dir() {
  if [ ! -d "$1" ]; then
    fail "Directory not found: $1"
  fi
}