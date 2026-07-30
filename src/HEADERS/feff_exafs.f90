!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! feffjl Phase 1: working in-process driver for the EXAFS chain.
!
! This supersedes HEADERS/feff.f90, which is stale and non-functional: it calls
! `ffmod1`, `ffmod2`, ... as subroutines, but every stage was declared
! `program ffmodN`, so it has never linked.  Phase 1 converted each stage body to
! `subroutine feff_<stage>()` (with the standalone executables preserved as thin
! `*_main.f90` shims), which makes a real in-process driver possible.
!
! Scope: the core EXAFS chain shaped for fitting,
!   rdinp -> atomic -> pot -> xsph -> fms -> path -> genfmt -> ff2x
! Deferred: dmdw, ldos, screen, crpa, opconsat, mkgtr, sfconv, compton, eels,
! rhorrp, rixs.  Every stage self-gates on its CONTROL card, so a stage whose
! flag is 0 is entered and returns without computing -- same as the executables.
!
! Phase 1 keeps the on-disk handoffs (.dimensions.dat, geom.dat, mod*.inp,
! pot.bin, phase.bin, feff.bin, paths.dat, ...) exactly as they are: the point of
! this phase is to prove one process can run the whole chain and reproduce the
! stock outputs bit-for-bit.  Replacing those handoffs with in-memory derived
! types is Phase 5.
!
! State handling: each stage still calls init_dimensions and its own work-module
! init_* routines, as it did when it was a program.  Those routines were made
! idempotent in Phase 1a (they deallocate-then-reallocate rather than
! bare-allocate), so re-entering a stage in the same process is safe and picks up
! whatever dimensions the current run wrote.  The driver therefore does not
! duplicate that reset logic -- it stays the single owner of ordering only.
!
! Phase-1 caveat, now closed: KSPACE/m_struct.f90::init_struct was guarded with
! `if(.not.allocated(...))`, so it reused arrays sized by the first run in the
! process.  Phase 3 replaced that with an extent test, since the C ABI makes
! repeated calls routine.
!
! feffjl Phase 3: the chain is now abort-aware.  Each stage's input-validation
! failures record themselves through COMMON/m_feff_status.f90 and return instead of
! calling `stop`, so the driver has to check between stages -- otherwise rdinp
! rejecting feff.inp would be followed by atomic and pot running on whatever
! mod*.inp happens to be left over from a previous run, which is worse than the
! `stop` it replaced.  Hence a check after every stage rather than only after
! rdinp: the status flag is shared, so any stage that learns to abort later is
! honoured here for free.
!
! Deliberately not a `goto`-based unwind: there is nothing to tear down at this
! level (each stage does its own par_barrier/par_end at its label 400), so a plain
! `return` is the whole of it.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

      subroutine feff_run_exafs

      use feff_status, only: feff_failed

      implicit none

      call feff_rdinp
      if (feff_failed()) return
      call feff_atomic
      if (feff_failed()) return
      call feff_pot
      if (feff_failed()) return
      call feff_xsph
      if (feff_failed()) return
      call feff_fms
      if (feff_failed()) return
      call feff_path
      if (feff_failed()) return
      call feff_genfmt
      if (feff_failed()) return
      call feff_ff2x

      return
      end subroutine feff_run_exafs
