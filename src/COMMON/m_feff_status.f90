!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! feffjl Phase 3: error status for library callers.
!
! FEFF's stages were written as standalone programs, so their input-validation
! failures are `stop` and `call par_stop(...)`.  Both terminate the process.  That
! is correct for an executable -- the shell sees a dead program and the user sees
! the message -- but fatal for a library: a malformed feff.inp handed to
! feff_run_exafs() through the C ABI would take the host down with it.  From a
! Julia session that means a lost REPL, and in a fit loop it means losing every
! result computed so far.
!
! This module is the place a stage records "I cannot continue, and here is why"
! without terminating.  The contract is deliberately minimal:
!
!   call feff_abort('message')   -- record the message, set the flag, return
!   if (feff_failed()) return    -- caller unwinds
!
! There is no non-local exit in Fortran, so unwinding is the caller's job: every
! routine between the abort and the ABI boundary has to check and return.  That
! is why only a bounded set of `stop`s is converted (see PHASE3_STATUS_AND_PLAN.md
! for exactly which, and which are knowingly left alone) rather than all ~170 in
! the tree.  A site that still calls `stop` still kills the host; the ABI
! documents that rather than pretending otherwise.
!
! Deliberately NOT part of COMMON/m_feff_capi.f90, and deliberately free of
! iso_c_binding: this is used by ordinary stage code (RDINP/consistency.f90 and
! friends), which must stay compilable and meaningful in the standalone
! executables where there is no C caller at all.  In those builds feff_abort
! behaves as a wlog + graceful return, which is strictly better than `stop`
! anyway.
!
! The message is also written through wlog, so the log6.dat/screen output of a
! failing run is unchanged from before the conversion.  Nothing about the
! diagnostics a human sees gets worse; the process merely survives.
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

      module feff_status

      implicit none

!     Length of the stored message.  Matches the character*512 slog buffers used
!     throughout the stages, plus room for a prefix.
      integer, parameter :: feff_msg_len = 1024

!     0 = no error.  Nonzero is returned to the C caller verbatim, so the values
!     are part of the ABI: keep them stable and only append.
      integer, parameter :: FEFF_OK           = 0
      integer, parameter :: FEFF_ERR_INPUT    = 1   ! bad feff.inp
      integer, parameter :: FEFF_ERR_WORKDIR  = 2   ! could not chdir / getcwd
      integer, parameter :: FEFF_ERR_NODATA   = 3   ! getter called before a run
      integer, parameter :: FEFF_ERR_BUFFER   = 4   ! caller's buffer too small

      integer, private :: err_code = FEFF_OK
      character(len=feff_msg_len), private :: err_msg = ' '

      contains

!     Record a failure and report it the way the stage would have anyway.  Does
!     NOT return control to the caller's caller -- see the module header.
      subroutine feff_abort(message)
      character*(*), intent(in) :: message
      call feff_abort_code(FEFF_ERR_INPUT, message)
      return
      end subroutine feff_abort

!     As feff_abort, with an explicit code for the non-input failure classes.
      subroutine feff_abort_code(code, message)
      integer, intent(in) :: code
      character*(*), intent(in) :: message

      logical :: log_is_open

!     First abort wins.  Unwinding is manual, so a routine that returns through
!     several levels can pass more than one check on the way out; keeping the
!     first message means the caller sees the actual cause rather than whatever
!     downstream symptom it produced.
      if (err_code .eq. FEFF_OK) then
         err_code = code
         err_msg = message

!        Only route through wlog once the log file exists.  wlog writes to unit
!        11 unconditionally (COMMON/wlog.f90:35-38) and its own comment says "the
!        log file is opened in the main program" -- in practice RDINP/rdinp.f90:143
!        opens log.dat there.  For a standalone executable that is always true by
!        the time anything reports an error.  Through the C ABI it is not: a bad
!        workdir is rejected before rdinp is ever entered, and the getters can be
!        called before any run at all.  Writing to an unopened unit makes gfortran
!        invent a file named fort.11 in whatever directory the host happened to be
!        standing in -- which is precisely the litter feff_exafs_run's chdir
!        handling exists to prevent, and it appeared in the caller's cwd on the
!        first run of the Phase-3 gate.
!
!        print, not silence, in that case: the message still has to reach a human
!        running this from a terminal.  It is the same text wlog would have
!        printed, so a failing run reads identically either way.
         inquire(unit=11, opened=log_is_open)
         if (log_is_open) then
            call wlog(' FEFF error: ' // trim(message))
         else
            print '(a)', ' FEFF error: ' // trim(message)
         endif
      endif
      return
      end subroutine feff_abort_code

      logical function feff_failed()
      feff_failed = (err_code .ne. FEFF_OK)
      return
      end function feff_failed

      integer function feff_status_code()
      feff_status_code = err_code
      return
      end function feff_status_code

      subroutine feff_status_message(message)
      character*(*), intent(out) :: message
      message = err_msg
      return
      end subroutine feff_status_message

!     Called by the ABI at the START of each run, not the end: a caller that
!     ignores the status of run N must still get a truthful answer for run N+1.
      subroutine feff_status_clear()
      err_code = FEFF_OK
      err_msg = ' '
      return
      end subroutine feff_status_clear

      end module feff_status
