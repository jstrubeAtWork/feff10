# This Makefile make with mkmkmf
# Define suffixes to look for
.SUFFIXES: .f .f90 .o .mod

SRCDIRS  =ATOM BAND COMMON COMPTON CRPA DEBYE DMDW EELS EELSMDFF ERRORMODS EXCH FF2X FMS FOVRG FULLSPECTRUM GENFMT HEADERS IOMODS KSPACE LDOS MATH MKGTR MODS PAR PATH POT RDINP RHORRP RIXS SCREEN SELF SFCONV TDLDA XSPH INPGEN
INCLUDEFLAGS=$(SRCDIRS:%=-I../%)

# Modified by FDV
# Removing band target until the module becomes more stable
#EXECUTABLES =atomic band compton crpa dmdw dym2feffinp eels ff2x fms fullspectrum genfmt ldos mkgtr opconsat path pot rdinp rhorrp rixs screen sfconv xsph 
# feffjl Phase 1: feff_exafs is the in-process EXAFS driver (one process runs
# rdinp..ff2x); the other entries are the unchanged standalone stages.
EXECUTABLES =atomic compton crpa dmdw dym2feffinp eels ff2x fms fullspectrum genfmt ldos mkgtr opconsat path pot rdinp rhorrp rixs screen sfconv xsph feff_exafs
EXECDIR=../bin/Seq

$(shell [ -e Compiler.mk ] || cp Compiler.mk.default Compiler.mk)

include Compiler.mk

ifneq ($(F90),gfortran)
#	FPPTASK=-DFEFF -fpp 
	FPPTASK=-DFEFF
endif

lbtool = ar ru
parmessg = "\n\n\n\tmodular src is in ../mod/MPI/\n\tPlease cd there and compile\n\twith the appropriate script."
messg = "\n\n\n\tmodular src is in ../mod/Seq/\n\tPlease cd there and compile\n\twith the appropriate script."
monmessg = "\n\n\n\tsrc is in ../mod/MONO/\n\tPlease cd there and compile\n\twith the appropriate script."
smessg1 = "\n\tBinaries are located in ../bin/"
smessg2 = "\n\tYou can use the script named\n\t\tfeff"
smessg3 = "\n\tlocated in ../bin/ to run feff"

# Source files needed by ATOM/atomic.f90.
include DEP/atomic$(DEPTYPE).mk
# Object files needed by ATOM/atomic.f90.
atomic_OBJ = ${atomicSRC:.f90=.o}
atomic_MODULES =${atomic_MODULESRC:.f90=.o}

# Source files needed by BAND/band.f90.
include DEP/band$(DEPTYPE).mk
# Object files needed by BAND/band.f90.
band_OBJ = ${bandSRC:.f90=.o}
band_MODULES =${band_MODULESRC:.f90=.o}

# Source files needed by COMPTON/compton.f90.
include DEP/compton$(DEPTYPE).mk
# Object files needed by COMPTON/compton.f90.
compton_OBJ = ${comptonSRC:.f90=.o}
compton_MODULES =${compton_MODULESRC:.f90=.o}

# Source files needed by CRPA/crpa.f90.
include DEP/crpa$(DEPTYPE).mk
# Object files needed by CRPA/crpa.f90.
crpa_OBJ = ${crpaSRC:.f90=.o}
crpa_MODULES =${crpa_MODULESRC:.f90=.o}

# Source files needed by DMDW/dmdw.f90.
include DEP/dmdw$(DEPTYPE).mk
# Object files needed by DMDW/dmdw.f90.
dmdw_OBJ = ${dmdwSRC:.f90=.o}
dmdw_MODULES =${dmdw_MODULESRC:.f90=.o}

# Source files needed by DMDW/dym2feffinp.f90.
include DEP/dym2feffinp$(DEPTYPE).mk
# Object files needed by DMDW/dym2feffinp.f90.
dym2feffinp_OBJ = ${dym2feffinpSRC:.f90=.o}
dym2feffinp_MODULES =${dym2feffinp_MODULESRC:.f90=.o}

# Source files needed by EELS/eels.f90.
include DEP/eels$(DEPTYPE).mk
# Object files needed by EELS/eels.f90.
eels_OBJ = ${eelsSRC:.f90=.o}
eels_MODULES =${eels_MODULESRC:.f90=.o}

# Source files needed by FF2X/ff2x.f90.
include DEP/ff2x$(DEPTYPE).mk
# Object files needed by FF2X/ff2x.f90.
ff2x_OBJ = ${ff2xSRC:.f90=.o}
ff2x_MODULES =${ff2x_MODULESRC:.f90=.o}

# feffjl Phase 1: in-process EXAFS driver (HEADERS/feff_exafs_main.f90).
# Source files needed by HEADERS/feff_exafs.f90.
include DEP/feff_exafs$(DEPTYPE).mk
# Object files needed by HEADERS/feff_exafs.f90.
feff_exafs_OBJ = ${feff_exafsSRC:.f90=.o}
feff_exafs_MODULES =${feff_exafs_MODULESRC:.f90=.o}

# feffjl Phase 2: the library is the same object set as the feff_exafs executable
# minus the `program` shim -- a shared object carrying MAIN__ would collide with
# the host program's main (and for Julia there is no Fortran main at all).
# feff_exafs_main.o is the only *_main object in this set: the eight stage shims
# are roots of their own DEP files, not reachable from HEADERS/feff_exafs.f90.
#
# feffjl Phase 3: COMMON/m_feff_capi.o is appended by hand, and has to be.
# Utility/mkdep.py builds each DEP file by walking `call` and `use` edges OUT from
# a root, so it only ever finds files the chain depends on.  The C ABI is the
# opposite direction: it depends on the chain and nothing in the chain depends on
# it, so no edge from HEADERS/feff_exafs.f90 reaches it and regen_dep.sh cannot
# help.  (COMMON/m_feff_status.o and COMMON/m_feff_results.o ARE found, because
# rdinp/ff2chi `use` them.)  Without this line the library links fine and simply
# exports none of the ABI -- which is why Phase-3 gate check A asserts every
# bind(c) symbol is present rather than trusting the link to have noticed.
#
# It goes in libfeff_MODULES, not libfeff_OBJ: the two lists are disjoint (checked
# -- 54 and 316 files, no overlap) and BOTH are passed to the linker, so naming it
# twice would be a duplicate-symbol error.  MODULES is the right list because
# m_feff_capi.f90 is a module and the *_MODULES list is what the Makefile compiles
# first, which the `use feff_capi` ordering requires.
libfeff_OBJ = $(filter-out ./HEADERS/feff_exafs_main.o,$(feff_exafs_OBJ))
libfeff_MODULES = $(feff_exafs_MODULES) ./COMMON/m_feff_capi.o

# Source files needed by FMS/fms.f90.
include DEP/fms$(DEPTYPE).mk
# Object files needed by FMS/fms.f90.
fms_OBJ = ${fmsSRC:.f90=.o}
fms_MODULES =${fms_MODULESRC:.f90=.o}

# Source files needed by FULLSPECTRUM/fullspectrum.f90.
include DEP/fullspectrum$(DEPTYPE).mk
# Object files needed by FULLSPECTRUM/fullspectrum.f90.
fullspectrum_OBJ = ${fullspectrumSRC:.f90=.o}
fullspectrum_MODULES =${fullspectrum_MODULESRC:.f90=.o}

# Source files needed by GENFMT/genfmt.f90.
include DEP/genfmt$(DEPTYPE).mk
# Object files needed by GENFMT/genfmt.f90.
genfmt_OBJ = ${genfmtSRC:.f90=.o}
genfmt_MODULES =${genfmt_MODULESRC:.f90=.o}

# Source files needed by LDOS/ldos.f90.
include DEP/ldos$(DEPTYPE).mk
# Object files needed by LDOS/ldos.f90.
ldos_OBJ = ${ldosSRC:.f90=.o}
ldos_MODULES =${ldos_MODULESRC:.f90=.o}

# Source files needed by MKGTR/mkgtr.f90.
include DEP/mkgtr$(DEPTYPE).mk
# Object files needed by MKGTR/mkgtr.f90.
mkgtr_OBJ = ${mkgtrSRC:.f90=.o}
mkgtr_MODULES =${mkgtr_MODULESRC:.f90=.o}

# Source files needed by OPCONSAT/opconsat.f90.
include DEP/opconsat$(DEPTYPE).mk
# Object files needed by OPCONSAT/opconsat.f90.
opconsat_OBJ = ${opconsatSRC:.f90=.o}
opconsat_MODULES =${opconsat_MODULESRC:.f90=.o}

# Source files needed by PATH/path.f90.
include DEP/path$(DEPTYPE).mk
# Object files needed by PATH/path.f90.
path_OBJ = ${pathSRC:.f90=.o}
path_MODULES =${path_MODULESRC:.f90=.o}

# Source files needed by POT/pot.f90.
include DEP/pot$(DEPTYPE).mk
# Object files needed by POT/pot.f90.
pot_OBJ = ${potSRC:.f90=.o}
pot_MODULES =${pot_MODULESRC:.f90=.o}

# Source files needed by RDINP/rdinp.f90.
include DEP/rdinp$(DEPTYPE).mk
# Object files needed by RDINP/rdinp.f90.
rdinp_OBJ = ${rdinpSRC:.f90=.o}
rdinp_MODULES =${rdinp_MODULESRC:.f90=.o}

# Source files needed by RHORRP/rhorrp.f90.
include DEP/rhorrp$(DEPTYPE).mk
# Object files needed by RHORRP/rhorrp.f90.
rhorrp_OBJ = ${rhorrpSRC:.f90=.o}
rhorrp_MODULES =${rhorrp_MODULESRC:.f90=.o}

# Source files needed by RIXS/rixs.f90.
include DEP/rixs$(DEPTYPE).mk
# Object files needed by RIXS/rixs.f90.
rixs_OBJ = ${rixsSRC:.f90=.o}
rixs_MODULES =${rixs_MODULESRC:.f90=.o}

# Source files needed by SCREEN/screen.f90.
include DEP/screen$(DEPTYPE).mk
# Object files needed by SCREEN/screen.f90.
screen_OBJ = ${screenSRC:.f90=.o}
screen_MODULES =${screen_MODULESRC:.f90=.o}

# Source files needed by SFCONV/sfconv.f90.
include DEP/sfconv$(DEPTYPE).mk
# Object files needed by SFCONV/sfconv.f90.
sfconv_OBJ = ${sfconvSRC:.f90=.o}
sfconv_MODULES =${sfconv_MODULESRC:.f90=.o}

# Source files needed by XSPH/xsph.f90.
include DEP/xsph$(DEPTYPE).mk
# Object files needed by XSPH/xsph.f90.
xsph_OBJ = ${xsphSRC:.f90=.o}
xsph_MODULES =${xsph_MODULESRC:.f90=.o}


########################################################################################################
###                                    MAKE TARGETS                                               ###
########################################################################################################

all:
	cp PAR/sequential.src PAR/parallel.f90
	mkdir -p ../bin/Seq
	make $(EXECUTABLES) "F90=$(F90)" "FLAGS=$(FLAGS)" "EXECDIR=../bin/Seq/"
	bash Utility/MkFeffScript seq
	cp `find ./ -name *.script` ../bin/Seq/
	echo -e $(smessg1) $(smessg2) $(smessg3)

mpi:
	cp PAR/parallel.src PAR/parallel.f90
	mkdir -p ../bin/MPI
	make $(EXECUTABLES) "F90=$(MPIF90)" "FLAGS=$(MPIFLAGS)" "EXECDIR=../bin/MPI/"
	bash Utility/MkFeffScript mpi
	cp `find ./ -name *.script` ../bin/MPI/
	echo -e $(parmessg1) $(parmessg2) $(parmessg3)

src:
	cp PAR/sequential.src PAR/parallel.f90
	perl Utility/make_modular_sourcefiles.pl

srcmpi:
	cp PAR/parallel.src PAR/parallel.f90
	perl Utility/make_modular_sourcefiles.pl mpi

deps:
	python Utility/mkdep.py

# Make clean
clean:
	rm -rf */*.o */*.mod
#####################################################################################################
###                                  END MAKE TARGETS                                             ###
#####################################################################################################
#####################################################################################################
###                                  atomic                                             ###
#####################################################################################################
atomic:$(EXECDIR)/atomic
$(EXECDIR)/atomic: $(atomic_MODULES) $(atomic_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(atomic_MODULES) $(atomic_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(atomic_MODULES) $(atomic_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END atomic                                             ###
#####################################################################################################

#####################################################################################################
###                                  band                                             ###
#####################################################################################################
band:$(EXECDIR)/band
$(EXECDIR)/band: $(band_MODULES) $(band_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(band_MODULES) $(band_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(band_MODULES) $(band_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END band                                             ###
#####################################################################################################

#####################################################################################################
###                                  compton                                             ###
#####################################################################################################
compton:$(EXECDIR)/compton
$(EXECDIR)/compton: $(compton_MODULES) $(compton_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(compton_MODULES) $(compton_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(compton_MODULES) $(compton_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END compton                                             ###
#####################################################################################################

#####################################################################################################
###                                  crpa                                             ###
#####################################################################################################
crpa:$(EXECDIR)/crpa
$(EXECDIR)/crpa: $(crpa_MODULES) $(crpa_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(crpa_MODULES) $(crpa_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(crpa_MODULES) $(crpa_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END crpa                                             ###
#####################################################################################################

#####################################################################################################
###                                  dmdw                                             ###
#####################################################################################################
dmdw:$(EXECDIR)/dmdw
$(EXECDIR)/dmdw: $(dmdw_MODULES) $(dmdw_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(dmdw_MODULES) $(dmdw_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(dmdw_MODULES) $(dmdw_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END dmdw                                             ###
#####################################################################################################

#####################################################################################################
###                                  dym2feffinp                                             ###
#####################################################################################################
dym2feffinp:$(EXECDIR)/dym2feffinp
$(EXECDIR)/dym2feffinp: $(dym2feffinp_MODULES) $(dym2feffinp_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(dym2feffinp_MODULES) $(dym2feffinp_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(dym2feffinp_MODULES) $(dym2feffinp_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END dym2feffinp                                             ###
#####################################################################################################

#####################################################################################################
###                                  eels                                             ###
#####################################################################################################
eels:$(EXECDIR)/eels
$(EXECDIR)/eels: $(eels_MODULES) $(eels_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(eels_MODULES) $(eels_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(eels_MODULES) $(eels_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END eels                                             ###
#####################################################################################################

#####################################################################################################
###                                  ff2x                                             ###
#####################################################################################################
ff2x:$(EXECDIR)/ff2x
$(EXECDIR)/ff2x: $(ff2x_MODULES) $(ff2x_OBJ)
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(ff2x_MODULES) $(ff2x_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(ff2x_MODULES) $(ff2x_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END ff2x                                             ###
#####################################################################################################
#####################################################################################################
###                                  feff_exafs                                             ###
#####################################################################################################
feff_exafs:$(EXECDIR)/feff_exafs
$(EXECDIR)/feff_exafs: $(feff_exafs_MODULES) $(feff_exafs_OBJ)
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(feff_exafs_MODULES) $(feff_exafs_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(feff_exafs_MODULES) $(feff_exafs_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END feff_exafs                                             ###
#####################################################################################################
#####################################################################################################
###                    libfeff  (feffjl Phase 2)                                              ###
#####################################################################################################
# Shared and static libraries exposing the EXAFS chain.
#
# feffjl Phase 3: the exported surface is now the bind(c) ABI in
# COMMON/m_feff_capi.f90 -- feff_run_exafs, feff_last_error, feff_get_nk,
# feff_get_chi, feff_get_xmu, feff_get_npaths, feff_abi_version -- with unmangled
# names, checked by gates/phase3_gate.sh.  The gfortran-mangled Fortran symbols
# (`feff_run_exafs_` and the eight `feff_<stage>_`) are still exported and
# gates/phase2_gate.sh still checks them: Phase 2's reentrancy matrix calls them
# directly, and they are what the k-space reentrancy fixture reaches
# `__struct_MOD_init_struct` through.  They are not API -- a caller should use the
# bind(c) names, which are the ones with a stable spelling across toolchains.
#
# Build with -fPIC. tools/build_lib.sh passes the right flags:
#   make lib "F90=gfortran" "FLAGS=$(GFORTRAN_LIB_FLAGS)" "LIBDIR=../lib"
LIBDIR = ../lib

lib: $(LIBDIR)/$(LIBFEFF_SO) $(LIBDIR)/$(LIBFEFF_A)

# -shared needs every input to be PIC; without -fPIC in FLAGS the link fails with
# "relocation R_X86_64_32S against `.bss' can not be used when making a shared
# object", which is the intended failure mode rather than a silently bad library.
$(LIBDIR)/$(LIBFEFF_SO): $(libfeff_MODULES) $(libfeff_OBJ)
	mkdir -p $(LIBDIR)
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -shared -Wl,-soname,$(LIBFEFF_SO) -o $@ $(libfeff_MODULES) $(libfeff_OBJ) $(LDFLAGS)
	@echo -e "built $@"

# `ar ru` (the existing lbtool) is deprecated in modern binutils and warns; use
# `ar rcs` so the static lib builds cleanly and has an index.
$(LIBDIR)/$(LIBFEFF_A): $(libfeff_MODULES) $(libfeff_OBJ)
	mkdir -p $(LIBDIR)
	rm -f $@
	ar rcs $@ $(libfeff_MODULES) $(libfeff_OBJ)
	@echo -e "built $@"
#####################################################################################################
###                              END libfeff                                             ###
#####################################################################################################

#####################################################################################################
###                                  fms                                             ###
#####################################################################################################
fms:$(EXECDIR)/fms
$(EXECDIR)/fms: $(fms_MODULES) $(fms_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(fms_MODULES) $(fms_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(fms_MODULES) $(fms_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END fms                                             ###
#####################################################################################################

#####################################################################################################
###                                  fullspectrum                                             ###
#####################################################################################################
fullspectrum:$(EXECDIR)/fullspectrum
$(EXECDIR)/fullspectrum: $(fullspectrum_MODULES) $(fullspectrum_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(fullspectrum_MODULES) $(fullspectrum_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(fullspectrum_MODULES) $(fullspectrum_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END fullspectrum                                             ###
#####################################################################################################

#####################################################################################################
###                                  genfmt                                             ###
#####################################################################################################
genfmt:$(EXECDIR)/genfmt
$(EXECDIR)/genfmt: $(genfmt_MODULES) $(genfmt_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(genfmt_MODULES) $(genfmt_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(genfmt_MODULES) $(genfmt_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END genfmt                                             ###
#####################################################################################################

#####################################################################################################
###                                  ldos                                             ###
#####################################################################################################
ldos:$(EXECDIR)/ldos
$(EXECDIR)/ldos: $(ldos_MODULES) $(ldos_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(ldos_MODULES) $(ldos_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(ldos_MODULES) $(ldos_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END ldos                                             ###
#####################################################################################################

#####################################################################################################
###                                  mkgtr                                             ###
#####################################################################################################
mkgtr:$(EXECDIR)/mkgtr
$(EXECDIR)/mkgtr: $(mkgtr_MODULES) $(mkgtr_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(mkgtr_MODULES) $(mkgtr_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(mkgtr_MODULES) $(mkgtr_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END mkgtr                                             ###
#####################################################################################################

#####################################################################################################
###                                  opconsat                                             ###
#####################################################################################################
opconsat:$(EXECDIR)/opconsat
$(EXECDIR)/opconsat: $(opconsat_MODULES) $(opconsat_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(opconsat_MODULES) $(opconsat_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(opconsat_MODULES) $(opconsat_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END opconsat                                             ###
#####################################################################################################

#####################################################################################################
###                                  path                                             ###
#####################################################################################################
path:$(EXECDIR)/path
$(EXECDIR)/path: $(path_MODULES) $(path_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(path_MODULES) $(path_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(path_MODULES) $(path_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END path                                             ###
#####################################################################################################

#####################################################################################################
###                                  pot                                             ###
#####################################################################################################
pot:$(EXECDIR)/pot
$(EXECDIR)/pot: $(pot_MODULES) $(pot_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(pot_MODULES) $(pot_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(pot_MODULES) $(pot_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END pot                                             ###
#####################################################################################################

#####################################################################################################
###                                  rdinp                                             ###
#####################################################################################################
rdinp:$(EXECDIR)/rdinp
$(EXECDIR)/rdinp: $(rdinp_MODULES) $(rdinp_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(rdinp_MODULES) $(rdinp_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(rdinp_MODULES) $(rdinp_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END rdinp                                             ###
#####################################################################################################

#####################################################################################################
###                                  rhorrp                                             ###
#####################################################################################################
rhorrp:$(EXECDIR)/rhorrp
$(EXECDIR)/rhorrp: $(rhorrp_MODULES) $(rhorrp_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(rhorrp_MODULES) $(rhorrp_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(rhorrp_MODULES) $(rhorrp_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END rhorrp                                             ###
#####################################################################################################

#####################################################################################################
###                                  rixs                                             ###
#####################################################################################################
rixs:$(EXECDIR)/rixs
$(EXECDIR)/rixs: $(rixs_MODULES) $(rixs_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(rixs_MODULES) $(rixs_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(rixs_MODULES) $(rixs_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END rixs                                             ###
#####################################################################################################

#####################################################################################################
###                                  screen                                             ###
#####################################################################################################
screen:$(EXECDIR)/screen
$(EXECDIR)/screen: $(screen_MODULES) $(screen_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(screen_MODULES) $(screen_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(screen_MODULES) $(screen_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END screen                                             ###
#####################################################################################################

#####################################################################################################
###                                  sfconv                                             ###
#####################################################################################################
sfconv:$(EXECDIR)/sfconv
$(EXECDIR)/sfconv: $(sfconv_MODULES) $(sfconv_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(sfconv_MODULES) $(sfconv_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(sfconv_MODULES) $(sfconv_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END sfconv                                             ###
#####################################################################################################

#####################################################################################################
###                                  xsph                                             ###
#####################################################################################################
xsph:$(EXECDIR)/xsph
$(EXECDIR)/xsph: $(xsph_MODULES) $(xsph_OBJ) 
	$(F90) $(FLAGS) $(INCLUDEFLAGS) -o $@ $(xsph_MODULES) $(xsph_OBJ) $(LDFLAGS)
	@echo -e $(F90) $(FLAGS) INCLUDEFLAGS -o $@ $(xsph_MODULES) $(xsph_OBJ) $(LDFLAGS)
#####################################################################################################
###                              END xsph                                             ###
#####################################################################################################

include DEP/dependencies.mk

.f90.mod:
	@echo "cd $(<D); $(F90) -c $(FLAGS) $(FPPTASK) INCLUDEFLAGS $(<F)"
	cd $(<D); $(F90) -c $(FLAGS) $(FPPTASK) $(INCLUDEFLAGS) $(<F)

# How to make a .o file from .f90
.f90.o:
# Modified by FDV
# Removing the -FR option, don't know what compiler this is for and might
# cause trouble with gofortran, for instance
#	@echo "cd $(<D); $(F90) -FR -c $(FLAGS) $(FPPTASK) INCLUDEFLAGS $(<F)"
#	@cd $(<D); $(F90) -FR -c $(FLAGS) $(FPPTASK) $(INCLUDEFLAGS) $(<F)
	@echo "cd $(<D); $(F90) -c $(FLAGS) $(FPPTASK) INCLUDEFLAGS $(<F)"
	cd $(<D); $(F90) -c $(FLAGS) $(FPPTASK) $(INCLUDEFLAGS) $(<F)

.f.o:
# Modified by FDV
# Removing the -FI option, don't know what compiler this is for and might
# cause trouble with gofortran, for instance
#	@echo "cd $(<D); $(F90) -FI -c $(FLAGS) $(FPPTASK) INCLUDEFLAGS $(<F)"
#	@cd $(<D); $(F90) -FI -c $(FLAGS) $(FPPTASK) $(INCLUDEFLAGS) $(<F)
	@echo "cd $(<D); $(F90) -c $(FLAGS) $(FPPTASK) INCLUDEFLAGS $(<F)"
	cd $(<D); $(F90) -c $(FLAGS) $(FPPTASK) $(INCLUDEFLAGS) $(<F)

	
%.o: %.mod
