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
! Known Phase-1 caveat: KSPACE/m_struct.f90::init_struct is guarded with
! `if(.not.allocated(...))`, so it reuses arrays sized by the first run in the
! process.  For repeated runs whose atom count grows this is a latent bug.  It is
! not exercised by the reciprocal-space-free EXAFS chain used here (ispace=0
! k-space paths are what consume it), but it must be fixed before feff_run_exafs
! is offered for arbitrary repeated inputs via the C ABI.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

      subroutine feff_run_exafs

      implicit none

      call feff_rdinp
      call feff_atomic
      call feff_pot
      call feff_xsph
      call feff_fms
      call feff_path
      call feff_genfmt
      call feff_ff2x

      return
      end subroutine feff_run_exafs
