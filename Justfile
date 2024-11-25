all: slint llint clean

test:
  nvim --headless -u test/minit.lua -c "PlenaryBustedDirectory tests/plenary/ {options}"

v:
  nvim -u test/minit.lua

w:
  ./scripts/bin/word

wl:
  ./scripts/bin/wordls

t:
  nvim --headless --noplugin -u test/minit.lua

slint :
  stylua --check .

clean:
	fd --glob '*-E' -x rm

llint:
  luacheck .


version:
  echo "0.1.0"

install:
  co -r ./scripts/bin/word


book:
  cd book && mdbook build

books:
  cd book && mdbook serve
