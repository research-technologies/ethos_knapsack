# frozen_string_literal: true
# see https://github.com/kbrock/bundler-inject/tree/gem_path

# specify one or more ruby files in this directory to be injected into bundler
# you can use `gem` to add new gems, `override_gem` to change an existing gem
# or `ensure_gem` to make sure a gem is there w/o worrying about if it is an
# override or not

# OVERRIDE Bulkrax (floating on main, unpinned) Gemfile bulkrax source: pins
#   to the commit where a dependency fix landed, instead of floating on main.
#   Keep: converts an unpinned floating dependency into a reviewable pin.
override_gem "bulkrax", github: "samvera/bulkrax", ref: "acc18e45a95e05d9f3c030ddef0a84a71a8d5975"
