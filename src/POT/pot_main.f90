!     feffjl Phase 1: standalone `pot` executable.
!
!     The stage body moved into subroutine feff_pot (POT/pot.f90) so it can also
!     be called in-process by feff_run_exafs.  This shim preserves the original
!     executable's behaviour exactly: run the stage, then stop.
!
!     Kept in its own file because the in-process driver links the stage objects
!     together, and a program unit in each of them would collide.
      program ffmod1
      call feff_pot
      stop
      end program ffmod1
