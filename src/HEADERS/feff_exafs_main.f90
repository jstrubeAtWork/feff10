!     feffjl Phase 1: driver executable for the in-process EXAFS chain.
!
!     Runs rdinp -> atomic -> pot -> xsph -> fms -> path -> genfmt -> ff2x in a
!     single process, producing the same outputs as running the eight standalone
!     executables in sequence.
!
!     Usage:
!       feff_exafs                  run the chain once on ./feff.inp
!       feff_exafs -2               run it twice on ./feff.inp
!       feff_exafs a.inp b.inp ...  for each argument: copy it to ./feff.inp,
!                                   then run the chain
!
!     The multi-run modes are the Phase-1 gate for stale SAVE/COMMON state: each
!     run must reproduce what the standalone executables produce for that input.
!     The different-input form is the stricter test, since it also catches
!     dimensions cached from the first run (see the init_struct caveat in
!     feff_exafs.f90).
!
!     Runs share one working directory by design: outputs and intermediate files
!     from run N are still on disk when run N+1 starts, exactly as they would be
!     if a caller re-invoked feff_run_exafs.  So this also exercises stale-file
!     contamination, not just stale in-memory state.
!
!     The input is copied with execute_command_line rather than by changing
!     directory, because rdinp opens the hardcoded name 'feff.inp' in the current
!     directory and Fortran has no standard chdir.
      program feff_exafs_main

      implicit none
      character*512 arg
      integer :: nrun, irun, nargs, cmdstat, exitstat
      logical :: copy_input

      nargs = command_argument_count()
      copy_input = .false.

      if (nargs .eq. 0) then
         nrun = 1
      else
         call get_command_argument(1, arg)
         if (trim(arg) .eq. '-2') then
            if (nargs .gt. 1) then
               print *, 'feff_exafs: -2 takes no further arguments'
               stop 1
            endif
            nrun = 2
         else
            nrun = nargs
            copy_input = .true.
         endif
      endif

      do irun = 1, nrun
         if (nrun .gt. 1) then
            print *, ''
            print *, '### feff_exafs: in-process run ', irun, ' of ', nrun
         endif

         if (copy_input) then
            call get_command_argument(irun, arg)
            print *, '### feff_exafs: input ', trim(arg)
            call execute_command_line('cp -- ' // trim(arg) // ' feff.inp',   &
     &           wait=.true., exitstat=exitstat, cmdstat=cmdstat)
            if (cmdstat .ne. 0 .or. exitstat .ne. 0) then
               print *, 'feff_exafs: could not copy ', trim(arg),             &
     &              ' to feff.inp'
               stop 1
            endif
         endif

         call feff_run_exafs
      enddo

      stop
      end program feff_exafs_main
