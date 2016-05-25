
MD_TARGETS := $(wildcard *.md)

TARGETS := $(MD_TARGETS:.md=.pdf)

.PHONY: all
all: $(TARGETS)
	@echo > /dev/null

%.pdf: %.md
	$(info [DOC] $< -> $@)
	@pandoc --from=markdown --latex-engine=xelatex --to=latex $< -o $@

.PHONY: clean
clean:
	$(RM) $(TARGETS)
