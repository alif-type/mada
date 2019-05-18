NAME=Mada
VERSION=1.4
LATIN=SourceSansPro

SRCDIR=sources
DOCDIR=documentation
BUILDDIR=build
TOOLDIR=tools
TESTDIR=tests
DIST=$(NAME)-$(VERSION)

PY ?= python
PREPARE=$(TOOLDIR)/prepare.py
MKSLANT=$(TOOLDIR)/mkslant.py
MKINST=$(TOOLDIR)/mkinstance.py

SAMPLE="صف خلق خود كمثل ٱلشمس إذ بزغت يحظى ٱلضجيع بها نجلاء معطار"

MASTERS=ExtraLight Regular Black ExtraLightItalic Italic BlackItalic ExtraLightSlanted Slanted BlackSlanted
FONTS=ExtraLight Light Regular Medium SemiBold Bold Black \
      ExtraLightItalic LightItalic Italic MediumItalic SemiBoldItalic BoldItalic BlackItalic

UFO=$(MASTERS:%=$(BUILDDIR)/$(NAME)-%.ufo)
OTF=$(FONTS:%=$(NAME)-%.otf)
TTF=$(FONTS:%=$(NAME)-%.ttf)
OTM=$(MASTERS:%=$(BUILDDIR)/masters/$(NAME)-%.otf)
TTM=$(MASTERS:%=$(BUILDDIR)/masters/$(NAME)-%.ttf)
OTV=$(NAME)-VF.otf
TTV=$(NAME)-VF.ttf
PDF=$(DOCDIR)/FontTable.pdf
PNG=$(DOCDIR)/FontSample.png
SMP=$(FONTS:%=%.png)

export SOURCE_DATE_EPOCH ?= 0

all: otf doc

otf: $(OTF)
ttf: $(TTF)
otv: $(OTV)
ttv: $(TTV)
doc: $(PDF) $(PNG)

SHELL=/usr/bin/env bash

.SECONDARY:

define prepare_masters
echo "   MASTER    $(notdir $(4))"
mkdir -p $(BUILDDIR)
$(PY) $(PREPARE) --version=$(VERSION)                                          \
                 --feature-file=$(3)                                           \
                 --out-file=$(4)                                               \
                 $(1) $(2)
endef

define generate_master
@echo "   MASTER    $(notdir $(3))"
mkdir -p $(BUILDDIR)/masters
PYTHONPATH=$(abspath $(TOOLDIR)):${PYTHONMATH}                                 \
fontmake -u $(abspath $(2))                                                    \
         --output=$(1)                                                         \
         --verbose=WARNING                                                     \
         --feature-writer KernFeatureWriter                                    \
         --feature-writer markFeatureWriter::MarkFeatureWriter                 \
         --production-names                                                    \
         --optimize-cff=0                                                      \
         --keep-overlaps                                                       \
	 --output-path=$(3)                                                    \
         ;
endef

define generate_variable
@echo " VARIABLE    $(notdir $(2))"
fonttools varLib                                                               \
        -q                                                                     \
        -o $(2)                                                                \
        --master-finder="$(BUILDDIR)/masters/{stem}.$(1)"                      \
        $(BUILDDIR)/$(NAME).designspace                                        \
        ;
endef

define generate_instance
@echo " INSTANCE    $(notdir $(3))"
@mkdir -p $(BUILDDIR)/instances
if [ -f $(BUILDDIR)/masters/$(notdir $(3)) ]; then                             \
       cp $(BUILDDIR)/masters/$(notdir $(3)) $(3);                             \
else                                                                           \
       $(PY) $(MKINST)                                                         \
             $(BUILDDIR)/$(NAME).designspace                                   \
             $(1)                                                              \
             $(NAME)-$(2)                                                      \
             $(3)                                                              \
             ;                                                                 \
fi
endef

$(NAME)-%.otf: $(BUILDDIR)/instances/$(NAME)-%.otf
	@cp $< $@

$(NAME)-%.ttf: $(BUILDDIR)/instances/$(NAME)-%.ttf
	@cp $< $@

$(BUILDDIR)/instances/$(NAME)-%.otf: $(OTV) $(BUILDDIR)/$(NAME).designspace
	@$(call generate_instance,$<,$(*F),$@)

$(BUILDDIR)/instances/$(NAME)-%.ttf: $(TTV) $(BUILDDIR)/$(NAME).designspace
	@$(call generate_instance,$<,$(*F),$@)

$(BUILDDIR)/masters/$(NAME)-%.otf: $(BUILDDIR)/$(NAME)-%.ufo
	@$(call generate_master,otf,$<,$@)

$(BUILDDIR)/masters/$(NAME)-%.ttf: $(BUILDDIR)/$(NAME)-%.ufo
	@$(call generate_master,ttf,$<,$@)

$(OTV): $(OTM) $(BUILDDIR)/$(NAME).designspace
	@$(call generate_variable,otf,$@)

$(TTV): $(TTM) $(BUILDDIR)/$(NAME).designspace
	@$(call generate_variable,ttf,$@)

$(BUILDDIR)/$(NAME)-ExtraLightItalic.ufo: $(BUILDDIR)/$(NAME)-ExtraLight.ufo
	@echo "    SLANT    $(@F)"
	@mkdir -p $(BUILDDIR)
	@$(PY) $(MKSLANT) $< $@ -15

$(BUILDDIR)/$(NAME)-Italic.ufo: $(BUILDDIR)/$(NAME)-Regular.ufo
	@echo "    SLANT    $(@F)"
	@mkdir -p $(BUILDDIR)
	@$(PY) $(MKSLANT) $< $@ -15

$(BUILDDIR)/$(NAME)-BlackItalic.ufo: $(BUILDDIR)/$(NAME)-Black.ufo
	@echo "    SLANT    $(@F)"
	@mkdir -p $(BUILDDIR)
	@$(PY) $(MKSLANT) $< $@ -15

$(BUILDDIR)/$(NAME)-ExtraLightSlanted.ufo: $(BUILDDIR)/$(NAME)-ExtraLight.ufo
	@echo "    SLANT    $(@F)"
	@mkdir -p $(BUILDDIR)
	@$(PY) $(MKSLANT) $< $@ 15

$(BUILDDIR)/$(NAME)-Slanted.ufo: $(BUILDDIR)/$(NAME)-Regular.ufo
	@echo "    SLANT    $(@F)"
	@mkdir -p $(BUILDDIR)
	@$(PY) $(MKSLANT) $< $@ 15

$(BUILDDIR)/$(NAME)-BlackSlanted.ufo: $(BUILDDIR)/$(NAME)-Black.ufo
	@echo "    SLANT    $(@F)"
	@mkdir -p $(BUILDDIR)
	@$(PY) $(MKSLANT) $< $@ 15

$(BUILDDIR)/$(NAME)-%.ufo: $(SRCDIR)/$(NAME)-%.ufo $(SRCDIR)/$(LATIN)/Roman/Instances/%/font.ufo $(SRCDIR)/$(NAME).fea $(PREPARE)
	@echo "     PREP    $(@F)"
	@rm -rf $@
	@mkdir -p $(BUILDDIR)
	@$(PY) $(PREPARE) --version=$(VERSION) --out-file=$@ $< $(word 2,$+)

$(BUILDDIR)/$(NAME).designspace: $(SRCDIR)/$(NAME).designspace
	@echo "      GEN    $(@F)"
	@mkdir -p $(BUILDDIR)
	@cp $< $@

$(PDF): $(NAME)-Regular.otf
	@echo "   SAMPLE    $(@F)"
	@mkdir -p $(DOCDIR)
	@fntsample --font-file $< --output-file $@.tmp                         \
		   --write-outline --use-pango                                 \
		   --style="header-font: Noto Sans Bold 12"                    \
		   --style="font-name-font: Noto Serif Bold 12"                \
		   --style="table-numbers-font: Noto Sans 10"                  \
		   --style="cell-numbers-font:Noto Sans Mono 8"
	@mutool clean -d -i -f -a $@.tmp $@
	@rm -f $@.tmp

$(PNG): $(OTF)
	@echo "   SAMPLE    $(@F)"
	@for f in $(FONTS); do \
	  hb-view $(NAME)-$$f.otf $(SAMPLE) --font-size=130 > $$f.png; \
	 done
	@convert $(SMP) -define png:exclude-chunks=date,time -gravity center -append $@
	@rm -rf $(SMP)

dist: otf ttf otv ttv doc
	@echo "     DIST    $(NAME)-$(VERSION)"
	@mkdir -p $(NAME)-$(VERSION)/{ttf,vf}
	@cp $(OTF) $(PDF) $(NAME)-$(VERSION)
	@cp $(TTF) $(NAME)-$(VERSION)/ttf
	@cp $(OTV)  $(NAME)-$(VERSION)/vf
	@cp $(TTV)  $(NAME)-$(VERSION)/vf
	@cp OFL.txt $(NAME)-$(VERSION)
	@sed -e "/^!\[Sample\].*./d" README.md > $(NAME)-$(VERSION)/README.txt
	@@echo "     ZIP    $(NAME)-$(VERSION)"
	@zip -rq $(NAME)-$(VERSION).zip $(NAME)-$(VERSION)

clean:
	@rm -rf $(BUILDDIR) $(OTF) $(TTF) $(OTV) $(TTV) $(PDF) $(PNG) $(NAME)-$(VERSION) $(NAME)-$(VERSION).zip
